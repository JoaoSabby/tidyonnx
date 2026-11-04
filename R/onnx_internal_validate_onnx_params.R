# Validate runtime and conversion settings before native resource allocation.
onnx_internal_validate_onnx_params <- function(params = list()) {
  defaults <- list(
    target_opset = 18L, ir_version = 8L, float_precision = "float32",
    embed_raw_bytes = TRUE, class_levels = NULL, execution_provider = "cpu",
    intra_op_threads = 1L, inter_op_threads = 1L, graph_opt_level = "all",
    log_severity = "error"
  )
  if (!is.list(params) || (length(params) &&
      (is.null(names(params)) || anyNA(names(params)) ||
       any(!nzchar(names(params))) || anyDuplicated(names(params))))) {
    stop("params must be a uniquely named list.", call. = FALSE)
  }
  unknown <- setdiff(names(params), names(defaults))
  if (length(unknown)) {
    stop("Unknown params: ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  defaults[names(params)] <- params
  # Whole-number bounds prevent native truncation and excessive worker requests.
  onnx_internal_integer_scalar <- function(value, minimum, maximum) {
    is.numeric(value) && length(value) == 1L && !is.na(value) &&
      is.finite(value) && value == floor(value) && value >= minimum &&
      value <= maximum
  }
  for (name in c("intra_op_threads", "inter_op_threads", "target_opset", "ir_version")) {
    bounds <- switch(name, target_opset = c(18, 21), ir_version = c(8, 10),
      inter_op_threads = c(1, 1), c(0, 1024))
    if (!onnx_internal_integer_scalar(defaults[[name]], bounds[1L], bounds[2L])) {
      stop("Invalid ", name, "; supported range: ", paste(bounds, collapse = ".."),
        ".", call. = FALSE)
    }
    defaults[[name]] <- as.integer(defaults[[name]])
  }
  choices <- list(
    float_precision = "float32", execution_provider = "cpu",
    graph_opt_level = c("all", "disable"),
    log_severity = c("verbose", "info", "warning", "error", "fatal")
  )
  for (name in names(choices)) {
    value <- defaults[[name]]
    if (!is.character(value) || length(value) != 1L || is.na(value) ||
        !value %in% choices[[name]]) {
      stop("Unsupported ", name, ". Supported values: ",
        paste(choices[[name]], collapse = ", "), ".", call. = FALSE)
    }
  }
  if (!is.logical(defaults$embed_raw_bytes) ||
      length(defaults$embed_raw_bytes) != 1L || is.na(defaults$embed_raw_bytes)) {
    stop("embed_raw_bytes must be TRUE or FALSE.", call. = FALSE)
  }
  levels <- defaults$class_levels
  if (!is.null(levels) && (!is.character(levels) || length(levels) < 2L ||
      anyNA(levels) || anyDuplicated(levels) || any(!nzchar(levels)))) {
    stop("class_levels must contain distinct nonempty strings.", call. = FALSE)
  }
  defaults
}

# Reject operation-specific settings that would otherwise be silently ignored.
onnx_internal_check_param_context <- function(params, operation) {
  runtime <- c("execution_provider", "intra_op_threads", "inter_op_threads",
    "graph_opt_level", "log_severity")
  allowed <- switch(operation, load = c(runtime, "embed_raw_bytes"),
    predict = runtime, inspect = runtime)
  unused <- setdiff(names(params), allowed)
  if (length(unused)) {
    stop("These params do not apply to ", operation, ": ",
      paste(unused, collapse = ", "), ".", call. = FALSE)
  }
  invisible(NULL)
}
