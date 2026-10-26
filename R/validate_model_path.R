#' @title Validate and normalize a model path
#' @description
#' A scalar file path is checked for directory, existence, and read constraints.
#' @param file A nonempty character scalar identifying a model file.
#' @param must_exist Logical; whether the file must already exist and be readable.
#' @return A normalized path with forward slashes.
#' @seealso [onnx_load()], [onnx_save()]
#' @references
#'   <https://stat.ethz.ch/R-manual/R-devel/library/base/html/normalizePath.html>
#' @examples
#' ValidatePath <- getFromNamespace("validate_model_path", "tidyonnx")
#' ValidatePath(tempfile(fileext = ".onnx"), FALSE)
#' @keywords internal
validate_model_path <- function(file, must_exist){
  if(!is.character(file) || length(file) != 1L || is.na(file) || !nzchar(file)){
    stop("file must be one nonempty file path.", call. = FALSE)
  }
  if(dir.exists(file) || !dir.exists(dirname(file))){
    stop("file must identify a file in an existing directory.", call. = FALSE)
  }
  if(must_exist && (!file.exists(file) || file.access(file, 4L) != 0L)){
    stop("Model file is missing or unreadable: ", file, call. = FALSE)
  }
  normalizePath(file, winslash = "/", mustWork = must_exist)
}
