# The cache environment survives object copies and is rehydrated after readRDS().
onnx_internal_model_from_bytes <- function(bytes, path, embed) {
  session <- onnx_internal_cpp_open_model(bytes)
  info <- onnx_internal_cpp_model_info(session)
  cache <- new.env(parent = emptyenv())
  cache$ptr <- session
  info$session_cache <- cache
  onnx_internal_model(
    session_ptr = session,
    model_path = path,
    raw_bytes = if (embed || !nzchar(path)) bytes else raw(),
    source_class = info$source_class,
    task_type = info$task_type,
    feature_names = info$feature_names,
    class_levels = info$class_levels,
    metadata = info
  )
}
