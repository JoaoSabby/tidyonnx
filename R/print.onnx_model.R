#' @title Print a native ONNX model summary
#' @description
#' Prediction task, feature count, tree count, and engine are displayed without
#' restoring a native session or exposing its external pointer.
#' @param x A native S7 ONNX model.
#' @param ... Reserved arguments; ignored for print compatibility.
#' @return The model, invisibly, after its summary has been printed.
#' @seealso [onnx_inspect()], [print.onnx_fit()]
#' @references <https://stat.ethz.ch/R-manual/R-devel/library/base/html/print.html>
#' @rawNamespace S3method(print,"tidyonnx::onnx_model",print.onnx_model)
print.onnx_model <- function(x, ...){
  cat("<tidyonnx model>\n")
  cat("Task: ", x@task_type, "\n", sep = "")
  cat("Features: ", length(x@feature_names), "\n", sep = "")
  cat("Trees: ", x@metadata$num_trees, "\n", sep = "")
  cat("Engine: native C (CPU)\n")
  invisible(x)
}
