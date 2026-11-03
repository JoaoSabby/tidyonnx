# Dispatch through S7 while preserving the direct functional interface.
onnx_save <- S7::new_generic(
  "onnx_save", "model",
  function(model, file, feature_names = NULL, params = list()) S7::S7_dispatch()
)
