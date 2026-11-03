# Preserve the fitted blueprint so raw predictor data receive training-time preprocessing.
onnx_internal_convert_workflow <- function(model, feature_names = NULL, params = list()) {
  onnx_internal_validate_onnx_params(params)
  if (!requireNamespace("workflows", quietly = TRUE) || !isTRUE(model$trained)) {
    return(onnx_internal_unrecognized_model(model, "Call fit() on the workflow first."))
  }
  fit <- workflows::extract_fit_parsnip(model)
  mold <- workflows::extract_mold(model)
  if (!is.null(feature_names) && !identical(feature_names, names(mold$predictors))) {
    stop("feature_names cannot rename a fitted workflow's predictor schema.", call. = FALSE)
  }
  converted <- onnx_convert(fit, names(mold$predictors), params)
  if (is.null(converted)) return(invisible(NULL))
  converted@metadata$blueprint <- mold$blueprint
  converted@metadata$source <- "fitted_workflow"
  converted
}
