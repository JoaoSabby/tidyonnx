# Dispatch on the fitted source model; ONNX objects are conversion results only.
onnx_convert <- S7::new_generic(
  "onnx_convert", "model",
  function(model, feature_names = NULL, params = list()) S7::S7_dispatch()
)
