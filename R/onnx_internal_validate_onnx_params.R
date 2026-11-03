# Validate tuning before any file write or native resource allocation.
onnx_internal_validate_onnx_params <- function(params = list()) {
  defaults <- list(
    target_opset = 18L, ir_version = 8L, float_precision = "float32",
    embed_raw_bytes = TRUE, class_levels = NULL, execution_provider = "cpu",
    intra_op_threads = 0L, inter_op_threads = 1L, graph_opt_level = "all",
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
  # Map independent settings and replace them together, without a mutable R loop.
  integer_names <- c("intra_op_threads", "inter_op_threads", "target_opset", "ir_version")
  defaults[integer_names] <- lapply(integer_names,
    onnx_internal_validate_integer_param, params = defaults)
  choices <- list(
    float_precision = "float32", execution_provider = "cpu",
    graph_opt_level = c("all", "disable"),
    log_severity = c("verbose", "info", "warning", "error", "fatal")
  )
  invisible(lapply(names(choices), function(name) {
    value <- defaults[[name]]
    if (!is.character(value) || length(value) != 1L || is.na(value) ||
        !value %in% choices[[name]]) {
      stop("Unsupported ", name, ". Route A supports: ",
        paste(choices[[name]], collapse = ", "), ".", call. = FALSE)
    }
  }))
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
