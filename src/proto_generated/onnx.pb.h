/* Audited field-number metadata for the supported ONNX 1.17 schema subset.
   These constants are maintained from inst/schema/onnx-ml.proto3; no generator
   or schema compiler is required by package installation. */
#ifndef TIDYONNX_ONNX_FIELDS_H
#define TIDYONNX_ONNX_FIELDS_H
enum OnnxModelFields {
  ONNX_IR_VERSION = 1, ONNX_PRODUCER_NAME = 2, ONNX_PRODUCER_VERSION = 3,
  ONNX_GRAPH = 7, ONNX_OPSET_IMPORT = 8, ONNX_METADATA_PROPS = 14
};
enum OnnxGraphFields {
  ONNX_GRAPH_NODE = 1, ONNX_GRAPH_NAME = 2, ONNX_GRAPH_INITIALIZER = 5,
  ONNX_GRAPH_INPUT = 11, ONNX_GRAPH_OUTPUT = 12
};
enum OnnxNodeFields {
  ONNX_NODE_INPUT = 1, ONNX_NODE_OUTPUT = 2, ONNX_NODE_NAME = 3,
  ONNX_NODE_OP_TYPE = 4, ONNX_NODE_ATTRIBUTE = 5, ONNX_NODE_DOMAIN = 7
};
#endif
