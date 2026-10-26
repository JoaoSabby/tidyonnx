#' @title Native ONNX serialization and prediction for fitted tree models
#' @description
#' Numerical XGBoost ensembles are converted to portable ONNX graphs and evaluated
#' by a bundled C engine. Post-fit adapters retain the preprocessing of fitted
#' parsnip models and workflows while replacing their fitted engine.
#' @details
#' Conversion supports numerical gbtree models with six built-in objectives.
#' Inference uses float32 comparisons, deterministic tree accumulation, and
#' optional OpenMP workers. A fitted workflow retains its R preprocessing;
#' only the numerical ensemble is represented in its ONNX graph.
#' @section Prediction lifecycle:
#' A fitted object is passed to [onnx_convert()] after model selection. Predictions
#' are obtained with [predict()] or [onnx_predict()]. Converted workflow objects
#' are persisted with [saveRDS()]; bare ensembles use [onnx_save()].
#' @seealso [onnx_convert()], [onnx_predict()], [onnx_save()], [onnx_inspect()]
#' @references
#' * ONNX intermediate representation: <https://onnx.ai/onnx/repo-docs/IR.html>.
#' * Tidymodels: <https://www.tidymodels.org/>.
#' * Model object reduction: <https://butcher.tidymodels.org/>.
#' @keywords internal
#' @useDynLib tidyonnx, .registration = TRUE
#' @importFrom S7 S7_inherits class_any class_character class_list class_raw
#'   methods_register new_class new_property
#' @importFrom cli cli_abort cli_warn
#' @importFrom jsonlite fromJSON
#' @importFrom parallel detectCores
#' @importFrom rlang caller_env check_dots_empty eval_tidy
#' @importFrom stats predict
#' @importFrom stringr str_c
#' @importFrom tibble as_tibble tibble
#' @importFrom tools md5sum
"_PACKAGE"
