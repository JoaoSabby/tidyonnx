# External pointers deliberately do not survive serialization; rebuild from portable bytes.
onnx_internal_ensure_active_session <- function(object) {
  cache <- object@metadata$session_cache
  if (is.environment(cache) && onnx_internal_cpp_session_alive(cache$ptr)) {
    object@session_ptr <- cache$ptr
    return(object)
  }
  if (onnx_internal_cpp_session_alive(object@session_ptr)) return(object)
  bytes <- object@raw_bytes
  if (!length(bytes)) bytes <- onnx_internal_read_model_bytes(object@model_path)
  session <- onnx_internal_cpp_open_model(bytes)
  # Replacing a referenced file must never silently change the feature/task contract.
  info <- onnx_internal_cpp_model_info(session)
  if (!identical(info$feature_names, object@feature_names) ||
      !identical(info$task_type, object@task_type) ||
      !identical(info$class_levels, object@class_levels)) {
    stop("The restored model no longer matches its saved schema.", call. = FALSE)
  }
  object@session_ptr <- session
  if (is.environment(cache)) cache$ptr <- session
  object
}
