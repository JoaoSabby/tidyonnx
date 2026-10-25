/* Nanopb supplies bounded wire decoding; returned spans borrow the input buffer. */
#ifndef TIDYONNX_PARSER_H
#define TIDYONNX_PARSER_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct {
  const uint8_t* data;
  size_t size;
} OnnxSpan;
typedef struct {
  uint32_t tag;
  int wire;
  uint64_t integer;
  float floating;
  OnnxSpan bytes;
} OnnxField;
/* Returns 1 for a field, 0 for end-of-message, and -1 for malformed input. */
int tidyonnx_next_field(OnnxSpan* stream, OnnxField* field);
int tidyonnx_read_packed_integer(OnnxSpan* stream, uint64_t* value);
int tidyonnx_read_packed_float(OnnxSpan* stream, float* value);
#ifdef __cplusplus
}
#endif
#endif
