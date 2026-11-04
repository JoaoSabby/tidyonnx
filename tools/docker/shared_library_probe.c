// Shared-library exports must remain callable after full profile LTO.
int onnx_internal_shared_value = 19;

// The exported function references shared data to verify both symbol kinds.
int onnx_internal_shared_probe(int value) {
  return value + onnx_internal_shared_value;
}
