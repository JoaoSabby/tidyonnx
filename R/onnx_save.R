# Write through a same-directory temporary file so conversion never truncates a destination.
onnx_save <- function(model, file, feature_names = NULL, params = list()){
  params <- validate_onnx_params(params)
  file <- validate_model_path(file, must_exist = FALSE)
  converted <- onnx_convert(model, feature_names, params)
  bytes <- converted@raw_bytes

  # Restore the serialized bytes when the converted model is file-backed
  if(!length(bytes)){
    bytes <- read_model_bytes(converted@model_path)
  }

  # Stage complete bytes in the destination directory for same-filesystem rename
  temporary <- tempfile(".tidyonnx-", tmpdir = dirname(file), fileext = ".onnx")
  on.exit(unlink(temporary), add = TRUE)
  writeBin(bytes, temporary)

  # Some filesystems do not support replacing an existing file by rename
  if(!suppressWarnings(file.rename(temporary, file))){
    if(!file.copy(temporary, file, overwrite = TRUE)){
      stop("Cannot write the destination file: ", file, call. = FALSE)
    }
  }

  # Resolve symlinks and Windows short names after writing the destination
  invisible(normalizePath(file, winslash = "/", mustWork = TRUE))
}
