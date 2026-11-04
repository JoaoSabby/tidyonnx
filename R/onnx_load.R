# Decode and validate the complete supported graph before publishing an S7 model.
onnx_load <- function(file, params = list()) {
  onnx_internal_check_param_context(params, "load")
  params <- onnx_internal_validate_onnx_params(params)
  file <- onnx_internal_validate_model_path(file, must_exist = TRUE)
  onnx_internal_model_from_bytes(onnx_internal_read_model_bytes(file), file,
    params$embed_raw_bytes, params)
}
