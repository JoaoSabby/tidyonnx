# Named tensors retain ONNX identities; this layer performs no tidy task interpretation.
onnx_run <- function(model, inputs) {
  if (!S7::S7_inherits(model, onnx_model)) {
    stop("model must be an onnx_model.", call. = FALSE)
  }
  model <- onnx_internal_ensure_active_session(model)
  if (!is.list(inputs) || is.data.frame(inputs) || is.null(names(inputs)) ||
      anyNA(names(inputs)) || any(!nzchar(names(inputs))) || anyDuplicated(names(inputs))) {
    stop("inputs must be a uniquely named list of numeric or integer tensors.", call. = FALSE)
  }
  expected <- vapply(model@metadata$inputs, `[[`, "", "name")
  if (length(inputs) != length(expected) || !setequal(names(inputs), expected)) {
    stop("Input tensor names must match: ", paste(expected, collapse = ", "), ".",
      call. = FALSE)
  }
  onnx_internal_run(model@session_ptr, inputs[expected])
}
