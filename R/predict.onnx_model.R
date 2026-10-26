#' @title Predict from a native S7 ONNX model
#' @description
#' The standard prediction generic delegates to [onnx_predict()].
#' @inheritParams onnx_predict
#' @param ... Reserved arguments; must be empty. Tuning uses params instead.
#' @return The same prediction tibble, vector, or matrix as [onnx_predict()].
#' @seealso [onnx_predict()], [predict.onnx_fit()]
#' @references <https://stat.ethz.ch/R-manual/R-devel/library/stats/html/predict.html>
#' @rawNamespace S3method(predict,"tidyonnx::onnx_model",predict.onnx_model)
predict.onnx_model <- function(object, new_data, type = NULL, ..., params = list()){
  if(length(list(...))) cli_abort("Unused prediction arguments; use params for tuning.")
  onnx_predict(object, new_data, type, params)
}
