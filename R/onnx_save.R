#' @title Save a numerical ensemble as a portable ONNX graph
#' @description
#' A supported ensemble is converted and written through a temporary file in the
#' destination directory. Existing files are replaced only after serialization.
#' @details
#' Replacement uses an atomic rename where supported. On systems that cannot
#' replace an existing file by rename, the original is moved to a backup and
#' restored if publication fails. A failed rollback reports the backup path.
#' @inheritParams onnx_convert
#' @param file A scalar destination path in an existing directory.
#' @return The normalized destination path, invisibly.
#' @section Preprocessing persistence:
#' A parsnip or workflow bundle contains R preprocessing that cannot be stored in
#' a tree-only ONNX graph. Saving such a bundle here is rejected. Use [saveRDS()]
#' for the complete bundle, or explicitly convert the extracted fitted engine
#' when a graph consuming already processed predictors is required.
#' @family ONNX model lifecycle
#' @seealso [onnx_load()], [onnx_convert()], [saveRDS()]
#' @references <https://onnx.ai/onnx/repo-docs/IR.html>
#' @examplesIf requireNamespace("xgboost") && requireNamespace("modeldata")
#' example("onnx_convert", package = "tidyonnx", ask = FALSE)
#' modelFile <- tempfile(fileext = ".onnx")
#' onnx_save(nativeModel, modelFile)
#' restoredModel <- onnx_load(modelFile)
#' unlink(modelFile)
#' @export
onnx_save <- function(model, file, feature_names = NULL, params = list()){
  params <- validate_onnx_params(params)
  file <- validate_model_path(file, must_exist = FALSE)
  converted <- onnx_convert(model, feature_names, params)
  if(inherits(converted, "onnx_fit")){
    cli_abort("Use {.fn saveRDS} to retain a prediction bundle's R preprocessing.")
  }
  bytes <- converted@raw_bytes
  if(!length(bytes)) bytes <- ReadBackingModel(converted)
  temporary <- tempfile(".tidyonnx-", tmpdir = dirname(file), fileext = ".onnx")
  on.exit(unlink(temporary), add = TRUE)
  writeBin(bytes, temporary)
  if(!suppressWarnings(file.rename(temporary, file))){
    if(!file.exists(file)) cli_abort("Cannot create the destination file {.file {file}}.")
    backup <- tempfile(".tidyonnx-backup-", tmpdir = dirname(file))
    if(!suppressWarnings(file.rename(file, backup))){
      cli_abort("Cannot replace the destination file {.file {file}}.")
    }
    if(!suppressWarnings(file.rename(temporary, file))){
      if(!suppressWarnings(file.rename(backup, file))){
        cli_abort("Publication failed. The original file is preserved at {.file {backup}}.")
      }
      cli_abort("Cannot replace {.file {file}}; the original file was restored.")
    }
    unlink(backup)
  }
  invisible(normalizePath(file, winslash = "/", mustWork = TRUE))
}
