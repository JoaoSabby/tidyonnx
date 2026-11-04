# Persist identical source models, input data, and original probabilities before timing.
arguments <- commandArgs(trailingOnly = TRUE)
directory <- arguments[[1L]]
dir.create(directory, recursive = TRUE, showWarnings = FALSE)
set.seed(20261103)
rows <- as.integer(Sys.getenv("BENCH_ROWS", "100000"))
rounds <- as.integer(strsplit(Sys.getenv("BENCH_TREES", "32,256"), ",", fixed = TRUE)[[1L]])
stopifnot(rows >= 1000L, length(rounds) == 2L, all(rounds > 0L))
features <- paste0("feature_", seq_len(16L))
training <- matrix(rnorm(4096L * 16L), ncol = 16L, dimnames = list(NULL, features))
inputs <- matrix(rnorm(rows * 16L), ncol = 16L, dimnames = list(NULL, features))
training[sample.int(length(training), floor(length(training) / 100L))] <- NA_real_
inputs[sample.int(length(inputs), floor(length(inputs) / 100L))] <- NA_real_
inputs[1L, ] <- NA_real_
signal <- replace(training, is.na(training), 0)
labels <- as.integer(signal[, 1L] - signal[, 2L] + signal[, 3L] * signal[, 4L] +
  rnorm(nrow(training), sd = 0.5) > 0)
saveRDS(inputs, file.path(directory, "inputs.rds"))
invisible(lapply(rounds, function(trees) {
  model <- xgboost::xgb.train(params = list(objective = "binary:logistic",
    nthread = 1L, max_depth = 4L, eta = 0.1, base_score = 0.3, seed = 20261103L),
    data = xgboost::xgb.DMatrix(training, label = labels, nthread = 1L),
    nrounds = trees, verbose = 0L)
  stem <- file.path(directory, paste0("trees-", trees))
  probability <- as.numeric(predict(model, xgboost::xgb.DMatrix(inputs, nthread = 1L)))
  # Keep the original probabilities immutable across every subsequent compiler build.
  saveRDS(probability, paste0(stem, "-reference.rds"))
  xgboost::xgb.save(model, paste0(stem, ".ubj"))
  converted <- tidyonnx::onnx_convert(model,
    params = list(class_levels = c("absence", "presence")))
  tidyonnx::onnx_save(converted, paste0(stem, ".onnx"))
}))
saveRDS(list(rows = rows, trees = rounds, features = features, seed = 20261103L),
  file.path(directory, "fixture.rds"))
writeLines(capture.output(sessionInfo()), file.path(directory, "fixture-session.txt"))
