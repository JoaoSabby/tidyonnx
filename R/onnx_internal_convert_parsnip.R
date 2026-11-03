# Recover fitted target labels and the binary event encoding chosen by parsnip.
onnx_internal_convert_parsnip <- function(model, feature_names = NULL, params = list()) {
  params <- onnx_internal_validate_onnx_params(params)
  if (!requireNamespace("parsnip", quietly = TRUE) ||
      !identical(model$spec$engine, "xgboost") || !inherits(model$fit, "xgb.Booster")) {
    return(onnx_internal_unrecognized_model(model, "A fitted XGBoost engine is required."))
  }
  target_levels <- model$lvl
  if (length(target_levels)) {
    if (!is.null(params$class_levels) && !identical(params$class_levels, target_levels)) {
      stop("class_levels must match the fitted parsnip outcome levels.", call. = FALSE)
    }
    event_level <- model$spec$eng_args$event_level
    event_level <- if (is.null(event_level)) "first" else rlang::quo_get_expr(event_level)
    if (!is.character(event_level) || length(event_level) != 1L ||
        is.na(event_level) || !event_level %in% c("first", "second")) {
      return(onnx_internal_unrecognized_model(model,
        "The fitted parsnip event_level must be a literal 'first' or 'second'."))
    }
    # XGBoost encodes the first factor level as 1 by default in binary parsnip fits.
    params$class_levels <- if (length(target_levels) == 2L && event_level == "first")
      rev(target_levels) else target_levels
  }
  converted <- onnx_internal_xgboost_build(model$fit, feature_names, params, target_levels)
  if (is.null(converted)) return(invisible(NULL))
  converted@metadata$target_levels <- target_levels
  converted
}
