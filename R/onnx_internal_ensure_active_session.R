# Serialized pointers are disposable; a source digest detects changed backing files.
onnx_internal_ensure_active_session <- function(object, params = NULL) {
  if (is.null(object@metadata$source_sha256)) {
    return(onnx_internal_upgrade_model(object, params))
  }
  cache <- object@metadata$session_cache
  if (is.null(params)) params <- cache$params
  params <- onnx_internal_validate_onnx_params(params)
  if (is.environment(cache) && identical(cache$params, params) &&
      onnx_internal_session_alive(cache$ptr)) {
    object@session_ptr <- cache$ptr
    return(object)
  }
  bytes <- object@raw_bytes
  if (!length(bytes)) bytes <- onnx_internal_read_model_bytes(object@model_path)
  if (!identical(digest::digest(bytes, algo = "sha256", serialize = FALSE),
      object@metadata$source_sha256)) {
    stop("The backing model file changed since this artifact was created.", call. = FALSE)
  }
  session <- onnx_internal_open_model(bytes, params)
  info <- onnx_internal_model_info(session)
  if (!identical(info$inputs, object@metadata$inputs) ||
      !identical(info$outputs, object@metadata$outputs) ||
      !identical(info$custom, object@metadata$custom)) {
    stop("The restored model no longer matches its saved schema.", call. = FALSE)
  }
  object@session_ptr <- session
  cache$ptr <- session
  cache$params <- params
  object
}

# Older embedded artifacts gain generic runtime metadata without trusting old pointers.
onnx_internal_upgrade_model <- function(object, params = NULL) {
  if (!length(object@raw_bytes)) {
    stop("Legacy file-backed artifacts have no source digest; reload the ONNX file explicitly.",
      call. = FALSE)
  }
  migrated <- onnx_internal_model_from_bytes(object@raw_bytes, object@model_path, TRUE,
    if (is.null(params)) list() else params)
  if (!identical(migrated@feature_names, object@feature_names) ||
      !identical(migrated@class_levels, object@class_levels) ||
      !identical(migrated@task_type, object@task_type)) {
    stop("Legacy artifact metadata disagrees with its embedded ONNX model.", call. = FALSE)
  }
  migrated
}
