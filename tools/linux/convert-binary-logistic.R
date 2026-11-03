# Reload the persisted source model in another R process and write a standalone ONNX graph.
arguments <- commandArgs(trailingOnly = TRUE)
output_directory <- if (length(arguments)) arguments[[1L]] else "/artifacts"
model <- xgboost::xgb.load(file.path(output_directory, "xgboost-model.ubj"))
converted <- tidyonnx::onnx_convert(model)
if (is.null(converted)) stop("The binary:logistic source was not recognized.")
tidyonnx::onnx_save(converted, file.path(output_directory, "converted-model.onnx"))
saveRDS(tidyonnx::onnx_inspect(converted), file.path(output_directory, "onnx-inspection.rds"))
cat("Persisted XGBoost binary:logistic model converted to ONNX.\n")
