#' @title Load and validate a portable ONNX ensemble
#' @description
#' A supported ONNX graph is fully decoded and validated before a native session
#' and its portable model object are constructed.
#' @details
#' The loader accepts one numerical ONNX-ML tree ensemble, optionally followed by
#' Sigmoid for regression, with a float32 input of shape `[N, P]`. Unsupported graph
#' operations and inconsistent topology are rejected before inference. Embedded
#' bytes are retained by default for automatic restoration after [readRDS()].
#' File-backed objects verify a saved file checksum before session restoration.
#' @param file A scalar readable file path. Empty and oversized files are rejected.
#' @inheritParams onnx_convert
#' @return A native S7 model with validated schema and an owned native session.
#' @family ONNX model lifecycle
#' @seealso [onnx_save()], [onnx_inspect()], [onnx_parameters]
#' @references <https://onnx.ai/onnx/operators/onnx_aionnxml_TreeEnsembleClassifier.html>
#' @examplesIf requireNamespace("xgboost") && requireNamespace("modeldata")
#' example("onnx_save", package = "tidyonnx", ask = FALSE)
#' @export
onnx_load <- function(file, params = list()){
  params <- validate_onnx_params(params)
  file <- validate_model_path(file, must_exist = TRUE)
  fileHash <- unname(md5sum(file))
  bytes <- read_model_bytes(file)
  if(!identical(fileHash, unname(md5sum(file)))){
    cli_abort("The model file changed while it was being read.")
  }
  model_from_bytes(bytes, file, params$embed_raw_bytes, fileHash)
}
