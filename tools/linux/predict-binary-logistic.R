# Load only the ONNX graph and run native inference in a fresh R process.
arguments <- commandArgs(trailingOnly = TRUE)
output_directory <- if (length(arguments)) arguments[[1L]] else "/artifacts"
new_data <- readRDS(file.path(output_directory, "new-data.rds"))
model <- tidyonnx::onnx_load(file.path(output_directory, "converted-model.onnx"))
probabilities <- tidyonnx::onnx_predict(model, new_data,
  type = "prob", params = list(intra_op_threads = 1L))
threaded <- tidyonnx::onnx_predict(model, new_data,
  type = "prob", params = list(intra_op_threads = 2L))
stopifnot(identical(probabilities, threaded))
stopifnot(identical(names(probabilities), c(".pred_0", ".pred_1")))
stopifnot(max(abs(rowSums(as.matrix(probabilities)) - 1)) <= 2e-7)
stopifnot(!any(c("xgboost", "parsnip", "workflows", "hardhat", "recipes") %in% loadedNamespaces()))
saveRDS(probabilities$.pred_1, file.path(output_directory, "onnx-predictions.rds"))
write.csv(data.frame(row_id = seq_len(nrow(probabilities)), probabilities),
  file.path(output_directory, "onnx-predictions.csv"), row.names = FALSE)
writeLines(c(R.version.string, paste("tidyonnx", utils::packageVersion("tidyonnx")),
  paste("loaded namespaces:", paste(loadedNamespaces(), collapse = ", ")),
  capture.output(sessionInfo())), file.path(output_directory, "inference-session.txt"))
cat("Native ONNX prediction passed without loading the source-model or tidymodels packages.\n")
