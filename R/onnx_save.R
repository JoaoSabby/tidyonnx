# Write through a same-directory temporary file so conversion never truncates a destination.
onnx_save <- function(model, file, feature_names = NULL, params = list()) {
  params <- validate_onnx_params(params)
  file <- validate_model_path(file, must_exist = FALSE)
  converted <- onnx_convert(model, feature_names, params)
  bytes <- converted@raw_bytes
  if (!length(bytes)) {
    bytes <- read_model_bytes(converted@model_path)
  }
  temporary <- tempfile(".tidyonnx-", tmpdir = dirname(file), fileext = ".onnx")
  on.exit(unlink(temporary), add = TRUE)
  writeBin(bytes, temporary)
  # Windows does not atomically replace an existing file with file.rename().
  if (file.exists(file)) {
    if (!file.copy(temporary, file, overwrite = TRUE)) {
      stop("Cannot replace the destination file: ", file, call. = FALSE)
    }
  } else if (!file.rename(temporary, file)) {
    stop("Cannot create the destination file: ", file, call. = FALSE)
  }
  # Resolve symlinks and Windows short names only after the destination exists.
  invisible(normalizePath(file, winslash = "/", mustWork = TRUE))
}
