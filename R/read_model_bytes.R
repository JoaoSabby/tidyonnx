# Bound file sizes to R's raw-vector reader limit and reject incomplete input.
read_model_bytes <- function(file) {
  size <- file.info(file)$size
  if (is.na(size) || size <= 0 || size > .Machine$integer.max) {
    stop("Model file must contain between 1 byte and 2 GB.", call. = FALSE)
  }
  bytes <- readBin(file, what = "raw", n = size)
  if (length(bytes) != size) stop("Model file could not be read completely.", call. = FALSE)
  bytes
}
