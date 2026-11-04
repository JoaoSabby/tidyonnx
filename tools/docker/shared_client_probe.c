#include <stdio.h>
extern int onnx_internal_shared_value;
extern int onnx_internal_shared_probe(int value);

// A separately linked process verifies both function and data exports.
int main(void) {
  if (onnx_internal_shared_value != 19 || onnx_internal_shared_probe(23) != 42) return 1;
  puts("Intel full-LTO shared function and data exports passed.");
  return 0;
}
