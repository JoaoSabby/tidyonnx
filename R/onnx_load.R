# Decode and validate the complete supported graph before publishing an S7 model.
onnx_load <- function(file, params = list()) {
  params <- validate_onnx_params(params)
  file <- validate_model_path(file, must_exist = TRUE)
  model_from_bytes(read_model_bytes(file), file, params$embed_raw_bytes)
}
