#' @title Restore a serialized native inference session
#' @description
#' A live session is reused, or rebuilt from embedded bytes or a verified file.
#' @details
#' A shared cache avoids repeated decoding when prediction is called on an RDS
#' object without reassigning its return value. Restored feature, task, and target
#' contracts must match the saved object before the session is published.
#' @param object A native S7 model.
#' @return The model with a live session and an updated shared cache.
#' @seealso [model_from_bytes()], [ReadBackingModel()]
#' @references <https://stat.ethz.ch/R-manual/R-devel/library/base/html/readRDS.html>
#' @keywords internal
ensure_active_session <- function(object){
  cache <- object@metadata$session_cache
  if(is.environment(cache) && cpp_session_alive(cache$ptr)){
    return(object)
  }
  if(cpp_session_alive(object@session_ptr)) return(object)
  bytes <- object@raw_bytes
  if(!length(bytes)) bytes <- ReadBackingModel(object)
  session <- cpp_open_model(bytes)
  info <- cpp_model_info(session)
  if(!identical(info$feature_names, object@feature_names) ||
     !identical(info$task_type, object@task_type) ||
     !identical(info$class_levels, object@class_levels)){
    cli_abort("The restored model no longer matches its saved schema.")
  }
  object@session_ptr <- session
  if(is.environment(cache)) cache$ptr <- session
  object
}

#' @title Read a checksum-verified backing model
#' @description
#' File bytes are read only when their checksum matches the saved model identity.
#' @details
#' The checksum is checked before and after reading. A same-schema replacement
#' therefore cannot silently change predictions after session restoration.
#' Checksums detect accidental file replacement and are not authentication.
#' @param object A file-backed native model.
#' @return The backing file as a nonempty raw vector.
#' @seealso [read_model_bytes()], [onnx_load()]
#' @references <https://stat.ethz.ch/R-manual/R-devel/library/tools/html/md5sum.html>
#' @keywords internal
ReadBackingModel <- function(object){
  file <- validate_model_path(object@model_path, must_exist = TRUE)
  expectedHash <- object@metadata$file_hash
  actualHash <- unname(md5sum(file))
  if(!is.null(expectedHash) && !identical(expectedHash, actualHash)){
    cli_abort("The backing model file no longer matches its saved checksum.")
  }
  bytes <- read_model_bytes(file)
  if(!identical(actualHash, unname(md5sum(file)))){
    cli_abort("The backing model file changed while it was being read.")
  }
  bytes
}

#' @title Obtain the live pointer shared by model copies
#' @description
#' The restored cache pointer is preferred over a stale serialized pointer slot.
#' @param object A model returned by [ensure_active_session()].
#' @return A live native external pointer.
#' @seealso [ensure_active_session()]
#' @references <https://cpp11.r-lib.org/>
#' @keywords internal
SessionPointer <- function(object){
  cache <- object@metadata$session_cache
  if(is.environment(cache) && cpp_session_alive(cache$ptr)) return(cache$ptr)
  object@session_ptr
}
