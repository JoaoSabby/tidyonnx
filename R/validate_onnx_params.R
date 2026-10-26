#' @title Validate ONNX conversion and prediction settings
#' @description
#' A uniquely named option list is merged with supported defaults and validated
#' before a file is written or a native prediction resource is allocated.
#' @details
#' Parameter lists apply to the current call. Serialization settings affect
#' conversion; thread settings affect prediction. Loading never converts a model.
#' Compatibility settings are validated but do not enable an external runtime.
#' @param params A uniquely named list. Unknown and duplicate entries are errors.
#' @return A complete named list with validated scalar types and target labels.
#' @section Conversion settings:
#' * target_opset = 18L: standard opset, from 18 through 21. ML opset is three.
#' * ir_version = 8L: model IR version, from eight through ten.
#' * float_precision = "float32": the only supported numeric graph precision.
#' * class_levels = NULL: unique nonempty class labels in encoded target order.
#' * iteration_range = "best": honor a saved early-stopping iteration when
#'   available. The alternative all exports every stored boosting iteration.
#' @section Persistence settings:
#' embed_raw_bytes = TRUE retains file bytes for RDS restoration. In-memory
#' conversion always retains bytes. With FALSE, restoration requires the original
#' file with a matching checksum. Existing objects are not relabeled by params.
#' @section Inference settings:
#' * intra_op_threads = 0L: auto-detected physical cores, bounded to 1024. Explicit
#'   values from one through 1024 are worker limits. Small batches use fewer.
#' * inter_op_threads = 1L: only sequential graph execution is supported.
#' * execution_provider = "cpu": the only available execution provider.
#' * graph_opt_level = "all": compatibility option; all and disable are accepted,
#'   and neither requests graph rewriting from the bundled engine.
#' * log_severity = "error": compatibility option accepting verbose, info,
#'   warning, error, or fatal; the bundled engine reports errors only.
#' @name onnx_parameters
#' @aliases validate_onnx_params
#' @seealso [onnx_convert()], [onnx_predict()], [onnx_load()]
#' @references <https://onnx.ai/onnx/repo-docs/Versioning.html>
#' @keywords internal
validate_onnx_params <- function(params = list()){
  defaults <- list(
    target_opset = 18L, ir_version = 8L, float_precision = "float32",
    iteration_range = "best",
    embed_raw_bytes = TRUE, class_levels = NULL, execution_provider = "cpu",
    intra_op_threads = 0L, inter_op_threads = 1L, graph_opt_level = "all",
    log_severity = "error"
  )
  if(!is.list(params) || (length(params) &&
     (is.null(names(params)) || anyNA(names(params)) ||
      any(!nzchar(names(params))) || anyDuplicated(names(params))))){
    cli_abort("{.arg params} must be a uniquely named list.")
  }
  unknown <- setdiff(names(params), names(defaults))
  if(length(unknown)) cli_abort("Unknown params: {.arg {unknown}}.")
  defaults[names(params)] <- params
  for(name in c("intra_op_threads", "inter_op_threads", "target_opset", "ir_version")){
    bounds <- switch(name, target_opset = c(18, 21), ir_version = c(8, 10),
                     inter_op_threads = c(1, 1), c(0, 1024))
    if(!IsScalarInteger(defaults[[name]], bounds[1L], bounds[2L])){
      cli_abort("Invalid {.arg {name}}; supported range: {bounds[1L]}..{bounds[2L]}.")
    }
    defaults[[name]] <- as.integer(defaults[[name]])
  }
  choices <- list(
    iteration_range = c("best", "all"),
    float_precision = "float32", execution_provider = "cpu",
    graph_opt_level = c("all", "disable"),
    log_severity = c("verbose", "info", "warning", "error", "fatal")
  )
  for(name in names(choices)){
    value <- defaults[[name]]
    if(!is.character(value) || length(value) != 1L || is.na(value) ||
       !value %in% choices[[name]]){
      cli_abort("Unsupported {.arg {name}}. Supported values: {.val {choices[[name]]}}.")
    }
  }
  if(!is.logical(defaults$embed_raw_bytes) ||
     length(defaults$embed_raw_bytes) != 1L || is.na(defaults$embed_raw_bytes)){
    cli_abort("{.arg embed_raw_bytes} must be TRUE or FALSE.")
  }
  classLevels <- defaults$class_levels
  if(!is.null(classLevels) && (!is.character(classLevels) || length(classLevels) < 2L ||
     anyNA(classLevels) || anyDuplicated(classLevels) || any(!nzchar(classLevels)))){
    cli_abort("{.arg class_levels} must contain distinct nonempty strings.")
  }
  defaults
}

#' @title Check a bounded integer-valued scalar
#' @description
#' Finite numeric values are checked before coercion to native integer storage.
#' @param value An object to validate.
#' @param minimum Inclusive lower bound.
#' @param maximum Inclusive upper bound.
#' @return A scalar logical, FALSE for missing, nonfinite, fractional, or long input.
#' @seealso [validate_onnx_params()]
#' @references <https://stat.ethz.ch/R-manual/R-devel/library/base/html/is.finite.html>
#' @examples
#' CheckInteger <- getFromNamespace("IsScalarInteger", "tidyonnx")
#' CheckInteger(4, 1, 8)
#' CheckInteger(NA_real_, 1, 8)
#' @keywords internal
IsScalarInteger <- function(value, minimum, maximum){
  is.numeric(value) && !is.object(value) && length(value) == 1L && !is.na(value) &&
    is.finite(value) && value == floor(value) && value >= minimum && value <= maximum
}
