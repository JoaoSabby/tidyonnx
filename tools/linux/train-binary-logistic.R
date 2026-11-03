# Train and persist the reference model and its predictions before ONNX conversion.
arguments <- commandArgs(trailingOnly = TRUE)
output_directory <- if (length(arguments)) arguments[[1L]] else "/artifacts"
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
set.seed(20261102)
feature_names <- paste0("feature_", seq_len(8L))
training_data <- matrix(rnorm(2400L * 8L), ncol = 8L,
  dimnames = list(NULL, feature_names))
new_data <- matrix(rnorm(1200L * 8L), ncol = 8L,
  dimnames = list(NULL, feature_names))
training_data[sample.int(length(training_data), 900L)] <- NA_real_
new_data[sample.int(length(new_data), 400L)] <- NA_real_

# Include missing-only, constant, and extreme finite rows without modifying row order.
new_data[1L, ] <- NA_real_
new_data[2L, ] <- 0
new_data[3L, ] <- 1
new_data[4L, ] <- -1
new_data[5L, ] <- 1e8
new_data[6L, ] <- -1e8
signal_data <- replace(training_data, is.na(training_data), 0)
signal <- 1.3 * signal_data[, 1L] - 0.8 * signal_data[, 2L] +
  signal_data[, 3L] * signal_data[, 4L] + sin(signal_data[, 5L])
labels <- as.integer(signal + rnorm(nrow(training_data), sd = 0.4) > 0)
training <- xgboost::xgb.DMatrix(training_data, label = labels, nthread = 2L)
model <- xgboost::xgb.train(
  params = list(objective = "binary:logistic", max_depth = 4L,
    eta = 0.15, base_score = 0.3, nthread = 2L, seed = 20261102L),
  data = training, nrounds = 45L, verbose = 0L
)
probability <- as.numeric(predict(model, xgboost::xgb.DMatrix(new_data, nthread = 2L)))
stopifnot(length(probability) == nrow(new_data), all(is.finite(probability)))
xgboost::xgb.save(model, file.path(output_directory, "xgboost-model.ubj"))
saveRDS(new_data, file.path(output_directory, "new-data.rds"))
saveRDS(list(data = training_data, labels = labels),
  file.path(output_directory, "training-data.rds"))
saveRDS(probability, file.path(output_directory, "xgboost-predictions.rds"))
write.csv(data.frame(row_id = seq_along(probability), probability = probability),
  file.path(output_directory, "xgboost-predictions.csv"), row.names = FALSE)
writeLines(c(R.version.string, paste("xgboost", utils::packageVersion("xgboost")),
  capture.output(sessionInfo())), file.path(output_directory, "training-session.txt"))
cat("Reference model and", length(probability), "predictions saved before conversion.\n")
