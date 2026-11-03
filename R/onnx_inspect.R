# Dispatch through S7 while preserving the direct functional interface.
onnx_inspect <- S7::new_generic(
  "onnx_inspect", "object",
  function(object, params = list()) S7::S7_dispatch()
)
