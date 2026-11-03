# Printing summarizes scientific model structure without exposing native pointers.
onnx_internal_print_method <- function(x, ...) {
  cat("<tidyonnx model>\n")
  cat("Task: ", x@task_type, "\n", sep = "")
  cat("Features: ", length(x@feature_names), "\n", sep = "")
  cat("Trees: ", x@metadata$num_trees, "\n", sep = "")
  cat("Engine: native C (CPU)\n")
  invisible(x)
}
