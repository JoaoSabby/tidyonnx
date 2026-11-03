# Validate source semantics before constructing the native ONNX representation.
onnx_internal_xgboost_build <- function(model, feature_names = NULL, params = list(),
    target_levels = NULL) {
  params <- onnx_internal_validate_onnx_params(params)
  if (!requireNamespace("xgboost", quietly = TRUE)) {
    return(onnx_internal_unrecognized_model(model, "The xgboost package is unavailable."))
  }
  learner <- onnx_internal_xgboost_document(model)
  learner$tidyonnx_target_levels <- target_levels
  if (!onnx_internal_xgboost_supported(learner)) {
    return(onnx_internal_unrecognized_model(model,
      "The booster, objective, split type, leaf shape, or target count is unsupported."))
  }
  # Early stopping needs explicit tree-range serialization before it can be portable.
  if (!is.null(xgboost::xgb.attr(model, "best_iteration"))) {
    return(onnx_internal_unrecognized_model(model,
      "Early-stopped models require tree-range serialization, which is not implemented."))
  }
  num_features <- as.integer(learner$learner_model_param$num_feature)
  stored_names <- unlist(learner$feature_names, use.names = FALSE)
  if (is.null(feature_names)) {
    feature_names <- if (length(stored_names)) stored_names else
      paste0("f", seq_len(num_features) - 1L)
  }
  if (!is.character(feature_names) || length(feature_names) != num_features ||
      anyNA(feature_names) || any(!nzchar(feature_names)) || anyDuplicated(feature_names)) {
    stop("feature_names must provide one distinct name per model feature.", call. = FALSE)
  }
  num_classes <- max(2L, as.integer(learner$learner_model_param$num_class))
  class_levels <- params$class_levels
  if (is.null(class_levels)) class_levels <- as.character(seq_len(num_classes) - 1L)
  if (length(class_levels) != num_classes) {
    stop("class_levels does not match the model's class count.", call. = FALSE)
  }
  # Recent XGBoost versions store vector intercepts in a JSON string.
  base_score <- learner$learner_model_param$base_score
  base_score <- if (startsWith(base_score, "[")) jsonlite::fromJSON(base_score) else
    as.numeric(base_score)
  bytes <- onnx_internal_cpp_serialize_model(learner, feature_names, class_levels,
    as.double(base_score), params$target_opset, params$ir_version)
  onnx_internal_model_from_bytes(bytes, "", TRUE)
}
