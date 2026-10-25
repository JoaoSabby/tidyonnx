# External pointers deliberately do not survive serialization; rebuild from portable bytes.
ensure_active_session <- function(object) {
  cache <- object@metadata$session_cache
  if (is.environment(cache) && cpp_session_alive(cache$ptr)) {
    object@session_ptr <- cache$ptr
    return(object)
  }
  if (cpp_session_alive(object@session_ptr)) return(object)
  bytes <- object@raw_bytes
  if (!length(bytes)) bytes <- read_model_bytes(object@model_path)
  session <- cpp_open_model(bytes)
  # Replacing a referenced file must never silently change the feature/task contract.
  info <- cpp_model_info(session)
  if (!identical(info$feature_names, object@feature_names) ||
      !identical(info$task_type, object@task_type) ||
      !identical(info$class_levels, object@class_levels)) {
    stop("The restored model no longer matches its saved schema.", call. = FALSE)
  }
  object@session_ptr <- session
  if (is.environment(cache)) cache$ptr <- session
  object
}
