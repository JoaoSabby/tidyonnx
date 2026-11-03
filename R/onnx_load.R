# Dispatch through S7 while preserving the direct functional interface.
onnx_load <- S7::new_generic(
  "onnx_load", "file",
  function(file, params = list()) S7::S7_dispatch()
)
