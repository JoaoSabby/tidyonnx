# Validate one bounded integer setting without coercing invalid values silently.
onnx_internal_validate_integer_param <- function(name, params) {
  bounds <- switch(name, target_opset = c(18, 21), ir_version = c(8, 10),
    inter_op_threads = c(1, 1), c(0, 1024))
  value <- params[[name]]
  valid <- is.numeric(value) && length(value) == 1L && !is.na(value) &&
    is.finite(value) && value == floor(value) && value >= bounds[1L] && value <= bounds[2L]
  if (!valid) {
    stop("Invalid ", name, "; supported range: ", paste(bounds, collapse = ".."),
      ".", call. = FALSE)
  }
  as.integer(value)
}
