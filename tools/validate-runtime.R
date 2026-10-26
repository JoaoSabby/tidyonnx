# Independent reference validation; this script is excluded from source-package builds.
library(tidyonnx)
library(xgboost)
library(stringr)

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 3L) {
  stop("Usage: Rscript tools/validate-runtime.R validator-executable runtime-library output-directory")
}
validator <- normalizePath(arguments[1L], mustWork = TRUE)
runtime <- normalizePath(arguments[2L], mustWork = TRUE)
output_directory <- arguments[3L]
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)

set.seed(821)
x <- matrix(rnorm(500 * 5), ncol = 5)
colnames(x) <- c("temperature", "rainfall", "altitude", "soil", "canopy")
x[sample(length(x), 180)] <- NA_real_
signal <- rowSums(replace(x, is.na(x), 0))
objectives <- c("binary:logistic", "binary:logitraw", "reg:squarederror",
  "reg:logistic", "multi:softprob", "multi:softmax")
scenarios <- data.frame(
  objective = c(objectives, "binary:logistic", "binary:logistic",
    "binary:logistic", "multi:softprob"),
  base = c(rep(0.2, 6), 0.8, 0.2, NA, NA),
  all_positive = c(rep(FALSE, 7), TRUE, FALSE, FALSE),
  stringsAsFactors = FALSE
)
scenarios$num_classes <- 3L
extra <- scenarios[5:6, ]
extra$num_classes <- 2L
scenarios <- rbind(scenarios, extra)
results <- vector("list", nrow(scenarios))
input_file <- file.path(output_directory, "features-float32.bin")
# R writes column-major; transpose once to construct the reference runtime's row-major input.
writeBin(as.numeric(t(x)), input_file, size = 4L, endian = "little")
for (index in seq_len(nrow(scenarios))) {
  scenario <- scenarios[index, ]
  objective <- scenario$objective
  multiclass <- startsWith(objective, "multi:")
  label <- if (multiclass) {
    if (scenario$num_classes == 2L) as.numeric(signal > 0) else
      as.numeric(cut(signal, c(-Inf, -0.7, 0.8, Inf))) - 1L
  } else if (objective == "reg:squarederror") signal else as.numeric(signal > 0)
  if (scenario$all_positive) label[] <- 1
  data <- xgb.DMatrix(x, label = label, nthread = 1L)
  params <- list(objective = objective, max_depth = 4L, eta = 0.2, nthread = 1L)
  if (!is.na(scenario$base)) params$base_score <- scenario$base
  if (multiclass) params$num_class <- scenario$num_classes
  fit <- xgb.train(params, data, nrounds = 25L, verbose = 0L)
  model_file <- file.path(output_directory, str_c("scenario-", index, ".onnx"))
  output_file <- file.path(output_directory, str_c("scenario-", index, "-ort.bin"))
  onnx_save(fit, model_file)
  native <- onnx_predict(model_file, x, type = "raw", params = list(intra_op_threads = 4L))
  native_matrix <- if (is.matrix(native)) native else matrix(native, ncol = 1L)
  reference <- predict(fit, data)
  if (objective == "binary:logistic") reference <- cbind(1 - reference, reference)
  if (objective == "multi:softmax") {
    margins <- predict(fit, data, outputmargin = TRUE)
    scores <- exp(margins - apply(margins, 1L, max))
    reference <- scores / rowSums(scores)
  }
  command_arguments <- vapply(c(runtime, model_file, input_file, nrow(x), ncol(x),
    output_file), shQuote, character(1))
  status <- system2(validator, command_arguments, stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(status, "status")) || !file.exists(output_file)) {
    stop("Reference runtime failed: ", paste(status, collapse = "\n"))
  }
  values <- readBin(output_file, "numeric", n = length(native_matrix), size = 4L,
    endian = "little")
  stopifnot(length(values) == length(native_matrix))
  ort <- matrix(values, nrow = nrow(x), byrow = TRUE)
  native_xgb <- max(abs(as.numeric(native_matrix) - as.numeric(reference)))
  native_ort <- max(abs(native_matrix - ort))
  xgb_ort <- max(abs(as.numeric(reference) - as.numeric(ort)))
  results[[index]] <- data.frame(
    scenario = index, objective = objective, base_score = scenario$base,
    all_positive = scenario$all_positive, rows = nrow(x), outputs = ncol(native_matrix),
    max_abs_native_xgboost = native_xgb, max_abs_native_ort = native_ort,
    max_abs_xgboost_ort = xgb_ort, runtime = paste(status, collapse = " ")
  )
  if (max(native_xgb, native_ort, xgb_ort) > 5e-6) {
    print(results[[index]]); print(head(cbind(native_matrix, ort, reference))); stop("Numerical reference validation failed for scenario ", index)
  }
}
result <- do.call(rbind, results)
write.csv(result, file.path(output_directory, "runtime-equivalence.csv"), row.names = FALSE)
print(result, row.names = FALSE)
writeLines(c(R.version.string, paste("xgboost", packageVersion("xgboost")),
  paste("S7", packageVersion("S7")), paste("cpp11", packageVersion("cpp11")),
  capture.output(sessionInfo())), file.path(output_directory, "session-info.txt"))
