# S7 objects expose a namespaced S3 class for compatibility with stats::predict().
predict.onnx_model <- function(object, new_data, type = NULL, ..., params = list()) {
  dots <- list(...)
  if (length(dots)) stop("Unused prediction arguments; use params for tuning.", call. = FALSE)
  onnx_predict(object, new_data, type, params)
}
