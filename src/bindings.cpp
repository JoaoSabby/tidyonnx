// cpp11 owns R protection and external-pointer finalization at the only C++/R boundary.
#include "model.h"
#include <climits>
#include <cstring>

namespace {
using namespace cpp11::literals;
cpp11::writable::strings r_strings(const std::vector<std::string>& values) {
  cpp11::writable::strings result(values.size());
  for (size_t index = 0; index < values.size(); ++index) result[index] = values[index];
  return result;
}
tidyonnx::Session* checked_session(SEXP pointer) {
  tidyonnx::require(TYPEOF(pointer) == EXTPTRSXP &&
    R_ExternalPtrTag(pointer) == Rf_install("tidyonnx_session_v1") &&
    R_ExternalPtrAddr(pointer) != nullptr, "The native session is missing or invalid.");
  return static_cast<tidyonnx::Session*>(R_ExternalPtrAddr(pointer));
}
}

[[cpp11::register]]
cpp11::writable::raws cpp_serialize_model(cpp11::list learner,
    cpp11::strings features, cpp11::strings levels, cpp11::doubles base_score,
    int opset, int ir_version) {
  // Registry entries are translation-unit adapters; the runtime never knows model classes.
  static const std::map<std::string, const tidyonnx::Serializer*> serializers = {
    {"xgb.Booster", &tidyonnx::xgboost_serializer()}
  };
  auto model = serializers.at("xgb.Booster")->serialize(
    learner, features, levels, base_score, opset, ir_version);
  // Validate the serialized graph before returning bytes to the R layer.
  tidyonnx::decode_model(model.bytes.data(), model.bytes.size());
  cpp11::writable::raws result(model.bytes.size());
  std::memcpy(RAW(result), model.bytes.data(), model.bytes.size());
  return result;
}

[[cpp11::register]]
cpp11::sexp cpp_open_model(cpp11::raws bytes) {
  tidyonnx::require(bytes.size() > 0, "An ONNX model cannot be empty.");
  auto session = tidyonnx::decode_model(RAW(bytes), static_cast<size_t>(bytes.size()));
  cpp11::external_pointer<tidyonnx::Session> pointer(session.get());
  session.release();
  R_SetExternalPtrTag(pointer, Rf_install("tidyonnx_session_v1"));
  return cpp11::sexp(static_cast<SEXP>(pointer));
}

[[cpp11::register]]
bool cpp_session_alive(SEXP pointer) {
  return TYPEOF(pointer) == EXTPTRSXP &&
    R_ExternalPtrTag(pointer) == Rf_install("tidyonnx_session_v1") &&
    R_ExternalPtrAddr(pointer) != nullptr;
}

[[cpp11::register]]
cpp11::writable::list cpp_model_info(SEXP pointer) {
  using namespace cpp11::literals;
  const auto* model = checked_session(pointer);
  return cpp11::writable::list({
    "producer"_nm = model->producer,
    "ir_version"_nm = model->ir_version,
    "opset"_nm = model->opset,
    "ml_opset"_nm = model->ml_opset,
    "source_class"_nm = model->source_class,
    "task_type"_nm = model->task_type,
    "label_type"_nm = model->label_type,
    "feature_names"_nm = r_strings(model->feature_names),
    "class_levels"_nm = r_strings(model->class_levels),
    "input_name"_nm = model->input_name,
    "output_names"_nm = r_strings(model->output_names),
    "num_graph_nodes"_nm = model->num_graph_nodes,
    "num_nodes"_nm = static_cast<double>(model->nodes.size()),
    "num_trees"_nm = static_cast<double>(model->roots.size()),
    "openmp"_nm = static_cast<bool>(tidyonnx_has_openmp())
  });
}

[[cpp11::register]]
cpp11::sexp cpp_predict_model(SEXP pointer, SEXP data, cpp11::integers indices,
    int rows, int threads) {
  auto* model = checked_session(pointer);
  tidyonnx::require(rows >= 0 && threads >= 1 && threads <= 1024,
    "Invalid row or thread count.");
  size_t columns_count = model->feature_names.size();
  tidyonnx::require(indices.size() == static_cast<R_xlen_t>(columns_count),
    "Incorrect feature count.");
  std::vector<TidyOnnxColumn> columns(columns_count);
  bool matrix = Rf_isMatrix(data);
  SEXP dimensions = Rf_getAttrib(data, R_DimSymbol);
  tidyonnx::require(matrix || TYPEOF(data) == VECSXP, "Invalid input storage.");
  if (matrix) {
    tidyonnx::require(TYPEOF(dimensions) == INTSXP && INTEGER(dimensions)[0] == rows,
      "Incorrect matrix row count.");
  }
  for (size_t column = 0; column < columns_count; ++column) {
    int index = indices[column] - 1;
    int available = matrix ? INTEGER(dimensions)[1] : static_cast<int>(Rf_xlength(data));
    tidyonnx::require(index >= 0 && index < available, "Invalid feature column index.");
    SEXP values = matrix ? data : VECTOR_ELT(data, index);
    tidyonnx::require(TYPEOF(values) == REALSXP || TYPEOF(values) == INTSXP,
      "Input columns must use numeric or integer storage.");
    tidyonnx::require(matrix || Rf_xlength(values) == rows, "Input columns have inconsistent lengths.");
    size_t offset = matrix ? static_cast<size_t>(index) * static_cast<size_t>(rows) : 0;
    columns[column].integer = TYPEOF(values) == INTSXP;
    columns[column].stride = 1;
    // Materialize ALTREP only on the main R thread before OpenMP can access storage.
    if (TYPEOF(values) == REALSXP) {
      const double* source = REAL(values) + offset;
      columns[column].data = source;
      for (int row = 0; row < rows; ++row) {
        tidyonnx::require(!std::isinf(source[row]), "Infinite predictor values are not supported.");
      }
    } else columns[column].data = INTEGER(values) + offset;
  }
  size_t output_size = static_cast<size_t>(rows) * static_cast<size_t>(model->num_targets);
  tidyonnx::require(output_size <= static_cast<size_t>(R_XLEN_T_MAX), "Prediction output is too large.");
  cpp11::writable::doubles output(output_size);
  int effective_threads = tidyonnx_has_openmp() ? std::min(threads, std::max(rows, 1)) : 1;
  std::vector<float> workspace(static_cast<size_t>(effective_threads) * model->num_targets);
  TidyOnnxEnsemble ensemble{
    model->nodes.data(), model->weights.data(), model->roots.data(),
    model->base_values.data(), model->roots.size(), model->num_targets, model->transform
  };
  // No R API may run inside the pure-C worker region.
  cpp11::check_user_interrupt();
  tidyonnx_predict(&ensemble, columns.data(), static_cast<size_t>(rows),
    REAL(output), effective_threads, workspace.data());
  cpp11::check_user_interrupt();
  if (model->task_type != "regression") {
    output.attr("dim") = cpp11::writable::integers({rows, model->num_targets});
  }
  return output;
}
