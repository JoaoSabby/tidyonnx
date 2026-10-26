#' @title Construct an owned model from validated ONNX bytes
#' @description
#' A native session and shared restoration cache are created from portable bytes.
#' @details
#' The cache environment is shared by object copies. External pointers are
#' finalized by cpp11 and rebuilt lazily after R serialization. In-memory models
#' always retain bytes, independently of the requested embedding policy.
#' @param bytes A nonempty raw vector containing an ONNX ModelProto.
#' @param path An existing model path, or an empty string for in-memory conversion.
#' @param embed Logical; whether bytes are retained for file-based objects.
#' @param fileHash Optional checksum of the backing file read by [onnx_load()].
#' @return A validated native S7 model with a shared session cache.
#' @seealso [ensure_active_session()], [onnx_load()]
#' @references <https://cpp11.r-lib.org/articles/cpp11.html>
#' @keywords internal
model_from_bytes <- function(bytes, path, embed, fileHash = NULL){
  session <- cpp_open_model(bytes)
  info <- cpp_model_info(session)
  cache <- new.env(parent = emptyenv())
  cache$ptr <- session
  info$session_cache <- cache
  info$file_hash <- fileHash
  onnx_model(
    session_ptr = session,
    model_path = path,
    raw_bytes = if(embed || !nzchar(path)) bytes else raw(),
    source_class = info$source_class,
    task_type = info$task_type,
    feature_names = info$feature_names,
    class_levels = info$class_levels,
    metadata = info
  )
}
