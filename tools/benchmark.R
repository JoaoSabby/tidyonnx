# Compare conversion revisions using the same stored engine and input data.
library(xgboost)
benchmarkLibrary <- Sys.getenv("TIDYONNX_BENCH_LIBRARY", unset = "")
if(nzchar(benchmarkLibrary)){
  library(tidyonnx, lib.loc = benchmarkLibrary)
} else library(tidyonnx)

arguments <- commandArgs(trailingOnly = TRUE)
if(length(arguments) != 3L){
  stop("Expected model file, predictor RDS file, and output CSV file.", call. = FALSE)
}
fittedModel <- xgb.load(arguments[1L])
predictorData <- readRDS(arguments[2L])
invisible(onnx_convert(fittedModel))
conversionSeconds <- numeric(7L)
for(repetition in seq_along(conversionSeconds)){
  invisible(gc())
  conversionSeconds[repetition] <- system.time(
    convertedModel <- onnx_convert(fittedModel)
  )[["elapsed"]]
}
reference <- predict(fittedModel, xgb.DMatrix(predictorData, nthread = 1L))
actual <- onnx_predict(convertedModel, predictorData, "raw",
                       params = list(intra_op_threads = 1L))
absoluteError <- max(abs(as.numeric(actual) - as.numeric(reference)))
errorLimit <- 5e-6 * max(1, max(abs(as.numeric(reference))))
stopifnot(absoluteError <= errorLimit)
results <- data.frame(
  version = as.character(packageVersion("tidyonnx", lib.loc = if(nzchar(benchmarkLibrary))
    benchmarkLibrary else NULL)),
  rows = nrow(predictorData),
  features = ncol(predictorData),
  graphTrees = onnx_inspect(convertedModel)$model$trees,
  repetitions = length(conversionSeconds),
  medianConversionSeconds = median(conversionSeconds),
  minimumConversionSeconds = min(conversionSeconds),
  maximumAbsoluteError = absoluteError,
  acceptedAbsoluteError = errorLimit,
  rVersion = as.character(getRversion()),
  platform = R.version$platform
)
write.csv(results, arguments[3L], row.names = FALSE)
print(results)
