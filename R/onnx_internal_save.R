# Write through a same-directory temporary file so conversion never truncates a destination.
onnx_internal_save <- function(model, file, feature_names = NULL, params = list()) {
  params <- onnx_internal_validate_onnx_params(params)
  file <- onnx_internal_validate_model_path(file, must_exist = FALSE)
  # ONNX results can be persisted without feeding them back into source conversion.
  converted <- if (S7::S7_inherits(model, onnx_internal_model)) {
    if (!is.null(feature_names) && !identical(feature_names, model@feature_names)) {
      stop("An ONNX model cannot be renamed during saving.", call. = FALSE)
    }
    onnx_internal_ensure_active_session(model)
  } else onnx_convert(model, feature_names, params)
  if (is.null(converted)) return(invisible(NULL))
  if (!is.null(converted@metadata$blueprint)) {
    stop("ONNX export cannot preserve workflow preprocessing; use saveRDS() for the complete model.",
      call. = FALSE)
  }
  bytes <- converted@raw_bytes
  if (!length(bytes)) {
    bytes <- onnx_internal_read_model_bytes(converted@model_path)
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
