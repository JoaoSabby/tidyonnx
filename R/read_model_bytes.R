#' @title Read a bounded ONNX model file
#' @description
#' A nonempty file is read completely into a raw vector before native decoding.
#' @details
#' Files larger than the supported signed integer reader limit are rejected.
#' A short read is treated as an error rather than passed to the parser.
#' @param file A scalar readable path validated by [validate_model_path()].
#' @return A nonempty raw vector containing the complete file.
#' @seealso [onnx_load()], [ReadBackingModel()]
#' @references <https://stat.ethz.ch/R-manual/R-devel/library/base/html/readBin.html>
#' @keywords internal
read_model_bytes <- function(file){
  size <- file.info(file)$size
  if(is.na(size) || size <= 0 || size > .Machine$integer.max){
    stop("Model file must contain between 1 byte and 2 GB.", call. = FALSE)
  }
  bytes <- readBin(file, what = "raw", n = size)
  if(length(bytes) != size) stop("Model file could not be read completely.", call. = FALSE)
  bytes
}
