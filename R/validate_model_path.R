# A single normalized path avoids vector recycling and ambiguous file connections.
validate_model_path <- function(file, must_exist) {
  if (!is.character(file) || length(file) != 1L || is.na(file) || !nzchar(file)) {
    stop("file must be one nonempty file path.", call. = FALSE)
  }
  if (dir.exists(file) || !dir.exists(dirname(file))) {
    stop("file must identify a file in an existing directory.", call. = FALSE)
  }
  if (must_exist && (!file.exists(file) || file.access(file, 4L) != 0L)) {
    stop("Model file is missing or unreadable: ", file, call. = FALSE)
  }
  normalizePath(file, winslash = "/", mustWork = must_exist)
}
