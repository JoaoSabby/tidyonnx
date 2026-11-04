# A wrapper supplies validated defaults without exposing a second native entry point.
onnx_internal_open_model <- function(bytes, params = list()) {
  if (!isTRUE(onnx_internal_runtime_state$initialized)) {
    onnx_internal_initialize_runtime(onnx_internal_runtime_state$path)
    onnx_internal_runtime_state$initialized <- TRUE
  }
  onnx_internal_create_session(bytes, onnx_internal_validate_onnx_params(params))
}

# Recognize only package metadata with a matching tensor contract; never infer tasks.
onnx_internal_model_from_bytes <- function(bytes, path, embed, params = list()) {
  params <- onnx_internal_validate_onnx_params(params)
  session <- onnx_internal_open_model(bytes, params)
  info <- onnx_internal_model_info(session)
  custom <- info$custom
  # Newline-delimited fields preserve the converter's ordered UTF-8 names.
  onnx_internal_split_names <- function(value) {
    if (is.null(value) || !nzchar(value)) character() else strsplit(value, "\n", fixed = TRUE)[[1L]]
  }
  features <- onnx_internal_split_names(custom$feature_names)
  levels <- onnx_internal_split_names(custom$class_levels)
  task <- if (is.null(custom$task_type)) "unknown" else custom$task_type
  if (task != "unknown") {
    input <- info$inputs
    classification <- startsWith(task, "classification")
    expected_outputs <- if (classification) c("label", "probabilities") else "prediction"
    score <- info$outputs[[length(info$outputs)]]
    expected_width <- if (classification) length(levels) else 1L
    if (length(input) != 1L || input[[1L]]$name != "features" ||
        input[[1L]]$element_type != "float32" || length(input[[1L]]$shape) != 2L ||
        !identical(input[[1L]]$shape[2L], as.double(length(features))) ||
        !identical(vapply(info$outputs, `[[`, "", "name"), expected_outputs) ||
        score$element_type != "float32" || length(score$shape) != 2L ||
        !identical(score$shape[2L], as.double(expected_width)) ||
        (classification && (length(levels) < 2L ||
          info$outputs[[1L]]$element_type != "int64" ||
          length(info$outputs[[1L]]$shape) != 1L))) {
      stop("Tidy task metadata does not match the ONNX tensor contract.", call. = FALSE)
    }
  }
  cache <- new.env(parent = emptyenv())
  cache$ptr <- session
  cache$params <- params
  info$session_cache <- cache
  info$source_sha256 <- digest::digest(bytes, algo = "sha256", serialize = FALSE)
  onnx_model(session_ptr = session, model_path = path,
    raw_bytes = if (embed || !nzchar(path)) bytes else raw(),
    source_class = if (is.null(custom$source_class)) "external" else custom$source_class,
    task_type = task, feature_names = features, class_levels = levels,
    target_name = if (is.null(custom$target_name)) "" else custom$target_name,
    metadata = info)
}
