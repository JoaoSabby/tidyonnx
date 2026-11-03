# Dispatch through S7 while preserving the direct functional interface.
onnx_predict <- S7::new_generic(
  "onnx_predict", "object",
  function(object, new_data, type = NULL, params = list()) S7::S7_dispatch()
)
