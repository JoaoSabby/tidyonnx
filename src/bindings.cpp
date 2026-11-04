// Serialization retains the bounded tree validator; prediction uses ONNX Runtime only.
#include "model.h"
#include <cstring>

// One serializer handles every supported XGBoost objective and portable score encoding.
[[cpp11::register]]
cpp11::writable::raws onnx_internal_serialize_model(cpp11::list learner,
    cpp11::strings features, cpp11::strings levels, cpp11::doubles base_score,
    int opset, int ir_version, std::string target_name, int positive_class) {
  auto model = tidyonnx::xgboost_serializer().serialize(
    learner, features, levels, base_score, opset, ir_version, target_name, positive_class);
  tidyonnx::decode_model(model.bytes.data(), model.bytes.size());
  cpp11::writable::raws result(model.bytes.size());
  std::memcpy(RAW(result), model.bytes.data(), model.bytes.size());
  return result;
}

// This isolated validator protects serializer invariants and never executes a graph.
[[cpp11::register]]
bool onnx_internal_validate_tree(cpp11::raws bytes) {
  tidyonnx::require(bytes.size() > 0, "An ONNX model cannot be empty.");
  tidyonnx::decode_model(RAW(bytes), static_cast<size_t>(bytes.size()));
  return true;
}
