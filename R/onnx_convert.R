# Conversion extracts stable model JSON; all ONNX wire encoding occurs in C++.
onnx_convert <- function(model, feature_names = NULL, params = list()) {
  params <- validate_onnx_params(params)
  if (S7::S7_inherits(model, onnx_model)) {
    if (!is.null(feature_names) && !identical(feature_names, model@feature_names)) {
      stop("An ONNX model cannot be renamed during conversion.", call. = FALSE)
    }
    return(ensure_active_session(model))
  }
  if (!inherits(model, "xgb.Booster")) {
    stop("No serializer is registered for model class: ",
      paste(class(model), collapse = "/"), ".", call. = FALSE)
  }
  if (!requireNamespace("xgboost", quietly = TRUE)) {
    stop("Install xgboost to convert xgb.Booster models.", call. = FALSE)
  }
  # Stable JSON preserves tree-to-class assignments, vector intercepts, and feature counts.
  document_text <- rawToChar(xgboost::xgb.save.raw(model, raw_format = "json"))
  # XGBoost JSON is UTF-8; mark raw bytes before jsonlite can apply locale conversion.
  Encoding(document_text) <- "UTF-8"
  document <- jsonlite::fromJSON(document_text, simplifyVector = FALSE)
  learner <- document$learner
  num_features <- as.integer(learner$learner_model_param$num_feature)
  stored_names <- unlist(learner$feature_names, use.names = FALSE)
  if (is.null(feature_names)) {
    feature_names <- if (length(stored_names)) stored_names else
      paste0("f", seq_len(num_features) - 1L)
  }
  if (!is.character(feature_names) || length(feature_names) != num_features ||
      anyNA(feature_names) || any(!nzchar(feature_names)) ||
      anyDuplicated(feature_names)) {
    stop("feature_names must provide one distinct name per model feature.", call. = FALSE)
  }
  num_classes <- max(2L, as.integer(learner$learner_model_param$num_class))
  class_levels <- params$class_levels
  if (is.null(class_levels)) class_levels <- as.character(seq_len(num_classes) - 1L)
  if (length(class_levels) != num_classes) {
    stop("class_levels does not match the model's class count.", call. = FALSE)
  }
  base_score <- learner$learner_model_param$base_score
  if (startsWith(base_score, "[")) {
    base_score <- jsonlite::fromJSON(base_score)
  } else {
    base_score <- as.numeric(base_score)
  }
  bytes <- cpp_serialize_model(learner, feature_names, class_levels,
    as.double(base_score), params$target_opset, params$ir_version)
  # In-memory objects always retain bytes because no file can restore their session.
  model_from_bytes(bytes, "", TRUE)
}
