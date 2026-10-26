// RAII owns every allocation; the C core only borrows immutable views.
#ifndef TIDYONNX_MODEL_H
#define TIDYONNX_MODEL_H
#include <cpp11.hpp>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <map>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>
#include "tidyonnx_api.h"
#include "onnx_parser.h"
#include "proto_generated/onnx.pb.h"

namespace tidyonnx {
inline void require(bool condition, const std::string& message) {
  if (!condition) throw std::runtime_error(message);
}
struct Attribute {
  int type = 0;
  std::vector<int64_t> integers;
  std::vector<float> floats;
  std::vector<std::string> strings;
};
struct Session {
  std::vector<TidyOnnxNode> nodes;
  std::vector<TidyOnnxWeight> weights;
  std::vector<int> roots;
  std::vector<float> base_values;
  std::vector<std::string> feature_names;
  std::vector<std::string> class_levels;
  std::vector<std::string> output_names;
  std::string source_class = "external";
  std::string producer;
  std::string input_name;
  std::string task_type;
  std::string label_type = "int64";
  int num_targets = 1;
  int num_graph_nodes = 1;
  int transform = 0;
  int ir_version = 0;
  int opset = 0;
  int ml_opset = 0;
  bool binary_threshold = false;
};
struct SerializedModel {
  std::vector<uint8_t> bytes;
};
// Serialization modules register through this interface without changing inference.
class Serializer {
 public:
  virtual ~Serializer() = default;
  virtual const char* source_class() const = 0;
  virtual SerializedModel serialize(cpp11::list learner,
    cpp11::strings features, cpp11::strings levels, cpp11::doubles base_score,
    int opset, int ir_version) const = 0;
};
const Serializer& xgboost_serializer();
std::unique_ptr<Session> decode_model(const uint8_t* data, size_t size);
}
#endif
