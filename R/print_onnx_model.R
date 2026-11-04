# Print only recognized artifact metadata and the actual execution backend.
print.onnx_model <- function(x, ...) {
  cat("<tidyonnx model>\n")
  cat("Task: ", x@task_type, "\n", sep = "")
  cat("Features: ", length(x@feature_names), "\n", sep = "")
  cat("Engine: ONNX Runtime 1.31.1 (CPU)\n")
  invisible(x)
}
