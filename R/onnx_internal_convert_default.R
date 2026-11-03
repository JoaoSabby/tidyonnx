# Validate call settings even when the source class has no registered converter.
onnx_internal_convert_default <- function(model, feature_names = NULL, params = list()) {
  onnx_internal_validate_onnx_params(params)
  onnx_internal_unrecognized_model(model)
}
