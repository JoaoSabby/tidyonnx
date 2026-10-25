/* All length checks precede pointer movement, including for unknown protobuf fields. */
#include "onnx_parser.h"
#include "nanopb/pb_decode.h"
#include <string.h>

int tidyonnx_read_packed_integer(OnnxSpan* stream, uint64_t* value) {
  pb_istream_t input = pb_istream_from_buffer(stream->data, stream->size);
  if (!pb_decode_varint(&input, value)) return 0;
  size_t consumed = stream->size - input.bytes_left;
  stream->data += consumed;
  stream->size = input.bytes_left;
  return 1;
}

int tidyonnx_read_packed_float(OnnxSpan* stream, float* value) {
  pb_istream_t input = pb_istream_from_buffer(stream->data, stream->size);
  if (!pb_decode_fixed32(&input, value)) return 0;
  stream->data += sizeof(float);
  stream->size = input.bytes_left;
  return 1;
}

int tidyonnx_next_field(OnnxSpan* stream, OnnxField* field) {
  if (stream->size == 0) return 0;
  pb_istream_t input = pb_istream_from_buffer(stream->data, stream->size);
  pb_wire_type_t wire;
  bool end = false;
  memset(field, 0, sizeof(*field));
  if (!pb_decode_tag(&input, &wire, &field->tag, &end) || end || !field->tag) return -1;
  field->wire = (int)wire;
  if (wire == PB_WT_VARINT) {
    if (!pb_decode_varint(&input, &field->integer)) return -1;
  } else if (wire == PB_WT_32BIT) {
    if (!pb_decode_fixed32(&input, &field->floating)) return -1;
  } else if (wire == PB_WT_64BIT) {
    uint64_t ignored;
    if (!pb_decode_fixed64(&input, &ignored)) return -1;
  } else if (wire == PB_WT_STRING) {
    uint64_t length;
    if (!pb_decode_varint(&input, &length) || length > input.bytes_left) return -1;
    size_t prefix = stream->size - input.bytes_left;
    field->bytes.data = stream->data + prefix;
    field->bytes.size = (size_t)length;
    if (!pb_read(&input, NULL, (size_t)length)) return -1;
  } else {
    return -1;
  }
  size_t consumed = stream->size - input.bytes_left;
  stream->data += consumed;
  stream->size = input.bytes_left;
  return 1;
}
