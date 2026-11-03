# Keep source dispatch separate from label-aware serialization used by adapters.
onnx_internal_convert_xgboost <- function(model, feature_names = NULL, params = list()) {
  onnx_internal_xgboost_build(model, feature_names, params)
}
