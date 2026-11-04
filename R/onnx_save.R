# Same-directory staging and backup allow restoration after a failed replacement.
onnx_save <- function(model, file, feature_names = NULL, params = list()) {
  onnx_internal_validate_onnx_params(params)
  file <- onnx_internal_validate_model_path(file, must_exist = FALSE)
  converted <- onnx_convert(model, feature_names, params)
  bytes <- converted@raw_bytes
  if (!length(bytes)) {
    bytes <- onnx_internal_read_model_bytes(converted@model_path)
    if (!identical(digest::digest(bytes, algo = "sha256", serialize = FALSE),
        converted@metadata$source_sha256)) {
      stop("The backing model file changed since this artifact was created.", call. = FALSE)
    }
  }
  onnx_internal_replace_file(bytes, file)
  invisible(normalizePath(file, winslash = "/", mustWork = TRUE))
}

# Injected file operations make replacement and rollback failure observable in tests.
onnx_internal_replace_file <- function(bytes, file, rename = file.rename) {
  temporary <- tempfile(".tidyonnx-", tmpdir = dirname(file), fileext = ".onnx")
  backup <- tempfile(".tidyonnx-backup-", tmpdir = dirname(file))
  on.exit(unlink(temporary), add = TRUE)
  writeBin(bytes, temporary)
  if (!identical(onnx_internal_read_model_bytes(temporary), bytes)) {
    stop("Staged model could not be written completely.", call. = FALSE)
  }
  existed <- file.exists(file)
  if (existed && !rename(file, backup)) {
    stop("Cannot stage the existing destination for replacement: ", file, call. = FALSE)
  }
  if (!rename(temporary, file)) {
    if (existed && !rename(backup, file)) {
      stop("Replacement and recovery failed; the original remains at: ", backup,
        call. = FALSE)
    }
    stop("Cannot replace the destination file; the original was preserved: ", file,
      call. = FALSE)
  }
  if (existed && unlink(backup) != 0L) {
    warning("Replacement succeeded; the backup could not be removed: ", backup,
      call. = FALSE)
  }
  invisible(file)
}
