// The runtime boundary uses the C ABI exclusively; C++ only provides resource ownership.
#include "runtime.h"
#include "model.h"
#include <climits>
#include <cstring>
#include <functional>
#ifndef _WIN32
#include <dlfcn.h>
#endif

namespace tidyonnx {
namespace {
std::shared_ptr<RuntimeLibrary> onnx_internal_library;
// Guards release partially constructed C resources when a later API call fails.
template <typename T> using OnnxOwned = std::unique_ptr<T, std::function<void(T*)>>;

// Inspect value categories before attempting tensor-specific metadata access.
TensorMetadata onnx_internal_tensor_metadata(RuntimeSession& owner, size_t index,
    bool input, OrtAllocator* allocator) {
  const auto* api = owner.library->api;
  TensorMetadata result;
  char* name = nullptr;
  owner.library->check(input ? api->SessionGetInputName(owner.session, index, allocator, &name) :
    api->SessionGetOutputName(owner.session, index, allocator, &name));
  OnnxOwned<char> name_guard(name, [allocator](char* p) { allocator->Free(allocator, p); });
  result.name = name;
  OrtTypeInfo* type = nullptr;
  owner.library->check(input ? api->SessionGetInputTypeInfo(owner.session, index, &type) :
    api->SessionGetOutputTypeInfo(owner.session, index, &type));
  OnnxOwned<OrtTypeInfo> type_guard(type, api->ReleaseTypeInfo);
  owner.library->check(api->GetOnnxTypeFromTypeInfo(type, &result.kind));
  if (result.kind != ONNX_TYPE_TENSOR) return result;
  const OrtTensorTypeAndShapeInfo* shape = nullptr;
  owner.library->check(api->CastTypeInfoToTensorInfo(type, &shape));
  owner.library->check(api->GetTensorElementType(shape, &result.element));
  size_t rank = 0;
  owner.library->check(api->GetDimensionsCount(shape, &rank));
  require(rank <= 32, "Tensor rank exceeds the supported limit of 32.");
  result.dimensions.resize(rank);
  std::vector<const char*> symbols(rank);
  owner.library->check(api->GetDimensions(shape, result.dimensions.data(), rank));
  owner.library->check(api->GetSymbolicDimensions(shape, symbols.data(), rank));
  for (const char* symbol : symbols) result.symbols.emplace_back(symbol ? symbol : "");
  return result;
}

// Only supported scalar storage types cross the R boundary without lossy coercion.
std::string onnx_internal_element_name(ONNXTensorElementDataType element) {
  switch (element) {
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT: return "float32";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE: return "float64";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32: return "int32";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64: return "int64";
    default: return "unsupported_" + std::to_string(element);
  }
}

// Preserve unknown dimensions and symbolic names rather than inventing matrix shapes.
cpp11::writable::list onnx_internal_tensor_list(const std::vector<TensorMetadata>& tensors) {
  using namespace cpp11::literals;
  cpp11::writable::list result(tensors.size());
  for (size_t i = 0; i < tensors.size(); ++i) {
    const auto& tensor = tensors[i];
    cpp11::writable::doubles dimensions(tensor.dimensions.size());
    cpp11::writable::strings symbols(tensor.symbols.size());
    for (size_t j = 0; j < tensor.dimensions.size(); ++j) {
      dimensions[j] = tensor.dimensions[j] < 0 ? NA_REAL : double(tensor.dimensions[j]);
      symbols[j] = tensor.symbols[j];
    }
    result[i] = cpp11::writable::list({"name"_nm = tensor.name,
      "kind"_nm = tensor.kind == ONNX_TYPE_TENSOR ? "tensor" : "unsupported",
      "element_type"_nm = onnx_internal_element_name(tensor.element),
      "shape"_nm = dimensions, "symbols"_nm = symbols});
  }
  return result;
}

// Bounds apply before multiplication, allocation or conversion to R dimensions.
size_t onnx_internal_tensor_size(const std::vector<int64_t>& dimensions, size_t width) {
  size_t count = 1;
  for (int64_t dimension : dimensions) {
    require(dimension >= 0 && dimension <= INT_MAX, "Unsupported tensor dimension.");
    require(dimension == 0 || count <= size_t(INT_MAX) / size_t(dimension),
      "Tensor element count exceeds the supported allocation limit.");
    count *= size_t(dimension);
  }
  require(count <= size_t(INT_MAX) / width, "Tensor byte size exceeds the 2 GB limit.");
  return count;
}

// Convert a row-major linear offset to R's column-major offset for arbitrary rank.
size_t onnx_internal_r_offset(size_t offset, const std::vector<int64_t>& dimensions) {
  size_t result = 0;
  size_t stride = 1;
  for (size_t i = 0; i < dimensions.size(); ++i) {
    size_t suffix = 1;
    for (size_t j = i + 1; j < dimensions.size(); ++j) suffix *= size_t(dimensions[j]);
    result += (offset / suffix % size_t(dimensions[i])) * stride;
    stride *= size_t(dimensions[i]);
  }
  return result;
}
}

RuntimeLibrary::RuntimeLibrary(const std::string& path) {
  try {
#ifdef _WIN32
    int length = MultiByteToWideChar(CP_UTF8, 0, path.c_str(), -1, nullptr, 0);
    std::vector<wchar_t> wide(length);
    MultiByteToWideChar(CP_UTF8, 0, path.c_str(), -1, wide.data(), length);
    handle = LoadLibraryExW(wide.data(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
    require(handle != nullptr, "Cannot load private ONNX Runtime library; Windows error " +
      std::to_string(GetLastError()) + ".");
    auto get_base = reinterpret_cast<const OrtApiBase* (ORT_API_CALL*)()>(
      GetProcAddress(static_cast<HMODULE>(handle), "OrtGetApiBase"));
#else
    handle = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
    require(handle != nullptr, "Cannot load private ONNX Runtime library.");
    auto get_base = reinterpret_cast<const OrtApiBase* (*)()>(dlsym(handle, "OrtGetApiBase"));
#endif
    require(get_base != nullptr, "Private runtime does not export OrtGetApiBase.");
    version = get_base()->GetVersionString();
    require(version == "1.31.1", "Private ONNX Runtime must be exactly version 1.31.1.");
    api = get_base()->GetApi(ORT_API_VERSION);
    require(api != nullptr, "ONNX Runtime header/library C API version mismatch.");
    check(api->CreateEnv(ORT_LOGGING_LEVEL_ERROR, "tidyonnx", &environment));
  } catch (...) {
#ifdef _WIN32
    if (handle) FreeLibrary(static_cast<HMODULE>(handle));
#else
    if (handle) dlclose(handle);
#endif
    handle = nullptr;
    throw;
  }
}

RuntimeLibrary::~RuntimeLibrary() {
  if (environment) api->ReleaseEnv(environment);
#ifdef _WIN32
  if (handle) FreeLibrary(static_cast<HMODULE>(handle));
#else
  if (handle) dlclose(handle);
#endif
}

void RuntimeLibrary::check(OrtStatus* status) const {
  if (!status) return;
  std::string message = api->GetErrorMessage(status);
  api->ReleaseStatus(status);
  throw std::runtime_error("ONNX Runtime: " + message);
}

RuntimeSession::RuntimeSession(cpp11::raws bytes, cpp11::list params) {
  library = onnx_internal_library;
  require(bool(library), "Private ONNX Runtime is not initialized.");
  require(bytes.size() > 0, "An ONNX model cannot be empty.");
  const auto* api = library->api;
  OrtSessionOptions* options = nullptr;
  library->check(api->CreateSessionOptions(&options));
  OnnxOwned<OrtSessionOptions> options_guard(options, api->ReleaseSessionOptions);
  library->check(api->SetIntraOpNumThreads(options, cpp11::as_cpp<int>(params["intra_op_threads"])));
  library->check(api->SetInterOpNumThreads(options, cpp11::as_cpp<int>(params["inter_op_threads"])));
  std::string optimization = cpp11::as_cpp<std::string>(params["graph_opt_level"]);
  library->check(api->SetSessionGraphOptimizationLevel(options,
    optimization == "disable" ? ORT_DISABLE_ALL : ORT_ENABLE_ALL));
  std::string severity = cpp11::as_cpp<std::string>(params["log_severity"]);
  const std::vector<std::string> severities{"verbose", "info", "warning", "error", "fatal"};
  library->check(api->SetSessionLogSeverityLevel(options,
    int(std::find(severities.begin(), severities.end(), severity) - severities.begin())));
  library->check(api->CreateSessionFromArray(library->environment, RAW(bytes), bytes.size(),
    options, &session));
  OnnxOwned<OrtSession> session_guard(session, api->ReleaseSession);
  OrtAllocator* allocator = nullptr;
  library->check(api->GetAllocatorWithDefaultOptions(&allocator));
  size_t count = 0;
  library->check(api->SessionGetInputCount(session, &count));
  require(count <= 1024, "Too many ONNX input tensors.");
  for (size_t i = 0; i < count; ++i) {
    inputs.push_back(onnx_internal_tensor_metadata(*this, i, true, allocator));
  }
  library->check(api->SessionGetOutputCount(session, &count));
  require(count <= 1024, "Too many ONNX output tensors.");
  for (size_t i = 0; i < count; ++i) {
    outputs.push_back(onnx_internal_tensor_metadata(*this, i, false, allocator));
  }
  OrtModelMetadata* model_metadata = nullptr;
  library->check(api->SessionGetModelMetadata(session, &model_metadata));
  OnnxOwned<OrtModelMetadata> metadata_guard(model_metadata, api->ReleaseModelMetadata);
  const std::vector<std::string> keys{"source_class", "task_type", "feature_names",
    "class_levels", "objective", "target_name", "binary_positive_class", "num_trees", "num_nodes",
    "num_graph_nodes", "opset", "ml_opset", "ir_version"};
  for (const auto& key : keys) {
    char* value = nullptr;
    library->check(api->ModelMetadataLookupCustomMetadataMap(model_metadata, allocator,
      ("tidyonnx." + key).c_str(), &value));
    OnnxOwned<char> value_guard(value, [allocator](char* p) { if (p) allocator->Free(allocator, p); });
    if (value) metadata.emplace_back(key, value);
  }
  char* producer_name = nullptr;
  library->check(api->ModelMetadataGetProducerName(model_metadata, allocator, &producer_name));
  OnnxOwned<char> producer_guard(producer_name,
    [allocator](char* p) { if (p) allocator->Free(allocator, p); });
  producer = producer_name ? producer_name : "";
  session_guard.release();
}

RuntimeSession::~RuntimeSession() {
  if (session) library->api->ReleaseSession(session);
}

RuntimeSession* onnx_internal_checked_session(SEXP pointer) {
  require(TYPEOF(pointer) == EXTPTRSXP &&
    R_ExternalPtrTag(pointer) == Rf_install("tidyonnx_ort_session_v2") &&
    R_ExternalPtrAddr(pointer) != nullptr, "The native session is missing or invalid.");
  return static_cast<RuntimeSession*>(R_ExternalPtrAddr(pointer));
}
}

// Namespace initialization supplies an absolute, hash-verified package-private path.
[[cpp11::register]]
std::string onnx_internal_initialize_runtime(std::string path) {
  tidyonnx::onnx_internal_library = std::make_shared<tidyonnx::RuntimeLibrary>(path);
  return tidyonnx::onnx_internal_library->version;
}

// Existing sessions retain shared ownership when the namespace releases its reference.
[[cpp11::register]]
void onnx_internal_release_runtime() {
  tidyonnx::onnx_internal_library.reset();
}

// Session handles are disposable caches; portable bytes remain in the S7 artifact.
[[cpp11::register]]
cpp11::sexp onnx_internal_create_session(cpp11::raws bytes, cpp11::list params) {
  auto session = std::make_unique<tidyonnx::RuntimeSession>(bytes, params);
  cpp11::external_pointer<tidyonnx::RuntimeSession> pointer(session.get());
  session.release();
  R_SetExternalPtrTag(pointer, Rf_install("tidyonnx_ort_session_v2"));
  return cpp11::sexp(static_cast<SEXP>(pointer));
}

// Serialized or foreign external pointers cannot satisfy the session ownership tag.
[[cpp11::register]]
bool onnx_internal_session_alive(SEXP pointer) {
  return TYPEOF(pointer) == EXTPTRSXP &&
    R_ExternalPtrTag(pointer) == Rf_install("tidyonnx_ort_session_v2") &&
    R_ExternalPtrAddr(pointer) != nullptr;
}

// Generic inspection reports runtime tensor metadata independently of tidy task metadata.
[[cpp11::register]]
cpp11::writable::list onnx_internal_model_info(SEXP pointer) {
  using namespace cpp11::literals;
  auto* owner = tidyonnx::onnx_internal_checked_session(pointer);
  cpp11::writable::list metadata(owner->metadata.size());
  cpp11::writable::strings names(owner->metadata.size());
  for (size_t i = 0; i < owner->metadata.size(); ++i) {
    names[i] = owner->metadata[i].first;
    metadata[i] = cpp11::as_sexp(owner->metadata[i].second);
  }
  metadata.names() = names;
  return cpp11::writable::list({"producer"_nm = owner->producer,
    "inputs"_nm = tidyonnx::onnx_internal_tensor_list(owner->inputs),
    "outputs"_nm = tidyonnx::onnx_internal_tensor_list(owner->outputs),
    "custom"_nm = metadata, "runtime_version"_nm = owner->library->version,
    "api_version"_nm = ORT_API_VERSION});
}

// Numeric tensors are explicitly reordered between R and ONNX contiguous storage.
[[cpp11::register]]
cpp11::writable::list onnx_internal_run(SEXP pointer, cpp11::list inputs) {
  using namespace tidyonnx;
  auto* owner = onnx_internal_checked_session(pointer);
  const auto* api = owner->library->api;
  require(size_t(inputs.size()) == owner->inputs.size(), "Incorrect ONNX input count.");
  OrtAllocator* allocator = nullptr;
  owner->library->check(api->GetAllocatorWithDefaultOptions(&allocator));
  std::vector<OnnxOwned<OrtValue>> values;
  std::vector<const OrtValue*> input_values;
  std::vector<const char*> input_names, output_names;
  std::map<std::string, int64_t> symbols;
  for (size_t i = 0; i < owner->inputs.size(); ++i) {
    const auto& meta = owner->inputs[i];
    require(meta.kind == ONNX_TYPE_TENSOR, "Unsupported non-tensor ONNX input: " + meta.name);
    SEXP source = inputs[i];
    require((TYPEOF(source) == REALSXP || TYPEOF(source) == INTSXP) && !Rf_isObject(source),
      "Inputs must be plain numeric or integer tensors.");
    SEXP dims = Rf_getAttrib(source, R_DimSymbol);
    std::vector<int64_t> dimensions;
    if (Rf_isNull(dims)) {
      if (meta.dimensions.empty()) require(Rf_xlength(source) == 1, "A scalar requires one value.");
      else dimensions.push_back(Rf_xlength(source));
    } else {
      require(TYPEOF(dims) == INTSXP && Rf_xlength(dims) <= 32, "Invalid tensor dimensions.");
      for (R_xlen_t j = 0; j < Rf_xlength(dims); ++j) dimensions.push_back(INTEGER(dims)[j]);
    }
    require(dimensions.size() == meta.dimensions.size(), "Tensor rank mismatch: " + meta.name);
    for (size_t j = 0; j < dimensions.size(); ++j) {
      require(meta.dimensions[j] < 0 || meta.dimensions[j] == dimensions[j],
        "Tensor shape mismatch: " + meta.name);
      if (!meta.symbols[j].empty()) {
        auto inserted = symbols.emplace(meta.symbols[j], dimensions[j]);
        require(inserted.second || inserted.first->second == dimensions[j],
          "Shared tensor dimension mismatch: " + meta.symbols[j]);
      }
    }
    std::string type = onnx_internal_element_name(meta.element);
    require(type == "float32" || type == "float64" || type == "int32" || type == "int64",
      "Unsupported ONNX input element type: " + type);
    size_t count = onnx_internal_tensor_size(dimensions, 8);
    require(count == size_t(Rf_xlength(source)), "Tensor storage and dimensions disagree.");
    OrtValue* tensor = nullptr;
    owner->library->check(api->CreateTensorAsOrtValue(allocator, dimensions.data(),
      dimensions.size(), meta.element, &tensor));
    values.emplace_back(tensor, api->ReleaseValue);
    void* buffer = nullptr;
    owner->library->check(api->GetTensorMutableData(tensor, &buffer));
    for (size_t j = 0; j < count; ++j) {
      size_t r_offset = onnx_internal_r_offset(j, dimensions);
      double value = TYPEOF(source) == REALSXP ? REAL(source)[r_offset] :
        (INTEGER(source)[r_offset] == NA_INTEGER ? NA_REAL : double(INTEGER(source)[r_offset]));
      require(!std::isinf(value), "Infinite tensor values are not supported.");
      if (type == "float32") {
        require(std::isnan(value) || std::abs(value) <= std::numeric_limits<float>::max(),
          "Tensor value exceeds float32 range.");
        static_cast<float*>(buffer)[j] = float(value);
      } else if (type == "float64") static_cast<double*>(buffer)[j] = value;
      else {
        require(std::isfinite(value) && std::floor(value) == value,
          "Integer tensors require exact, non-missing integer values.");
        if (type == "int32") {
          require(value > INT_MIN && value <= INT_MAX, "Value has no exact base R int32 representation.");
          static_cast<int32_t*>(buffer)[j] = int32_t(value);
        } else {
          require(std::abs(value) <= 9007199254740992.0,
            "int64 values outside +/-2^53 have no exact base R representation.");
          static_cast<int64_t*>(buffer)[j] = int64_t(value);
        }
      }
    }
    input_names.push_back(meta.name.c_str());
    input_values.push_back(tensor);
  }
  for (const auto& meta : owner->outputs) {
    require(meta.kind == ONNX_TYPE_TENSOR, "Unsupported non-tensor ONNX output: " + meta.name);
    std::string type = onnx_internal_element_name(meta.element);
    require(type == "float32" || type == "float64" || type == "int32" || type == "int64",
      "Unsupported ONNX output element type: " + type);
    // Unresolved data-dependent shapes are rejected before OrtRun can allocate output.
    auto bounded_dimensions = meta.dimensions;
    for (size_t j = 0; j < bounded_dimensions.size(); ++j) {
      if (bounded_dimensions[j] >= 0) continue;
      auto found = symbols.find(meta.symbols[j]);
      require(!meta.symbols[j].empty() && found != symbols.end(),
        "Cannot bound a data-dependent ONNX output shape: " + meta.name);
      bounded_dimensions[j] = found->second;
    }
    onnx_internal_tensor_size(bounded_dimensions, 8);
    output_names.push_back(meta.name.c_str());
  }
  std::vector<OrtValue*> output_values(output_names.size(), nullptr);
  // Run can produce partial outputs on error; the guard covers every returned slot.
  auto release_outputs = [&api](std::vector<OrtValue*>* outputs) {
    for (auto* value : *outputs) if (value) api->ReleaseValue(value);
  };
  std::unique_ptr<std::vector<OrtValue*>, decltype(release_outputs)>
    output_guard(&output_values, release_outputs);
  cpp11::check_user_interrupt();
  owner->library->check(api->Run(owner->session, nullptr, input_names.data(),
    input_values.data(), input_values.size(), output_names.data(), output_names.size(),
    output_values.data()));
  cpp11::check_user_interrupt();
  cpp11::writable::list result(output_values.size());
  cpp11::writable::strings names(output_values.size());
  for (size_t i = 0; i < output_values.size(); ++i) {
    ONNXType kind;
    owner->library->check(api->GetValueType(output_values[i], &kind));
    require(kind == ONNX_TYPE_TENSOR, "Runtime returned an unsupported non-tensor value.");
    OrtTensorTypeAndShapeInfo* shape = nullptr;
    owner->library->check(api->GetTensorTypeAndShape(output_values[i], &shape));
    OnnxOwned<OrtTensorTypeAndShapeInfo> shape_guard(shape, api->ReleaseTensorTypeAndShapeInfo);
    size_t rank = 0;
    owner->library->check(api->GetDimensionsCount(shape, &rank));
    require(rank <= 32, "Output tensor rank exceeds 32.");
    std::vector<int64_t> dimensions(rank);
    owner->library->check(api->GetDimensions(shape, dimensions.data(), rank));
    size_t count = onnx_internal_tensor_size(dimensions, 8);
    size_t actual = 0;
    owner->library->check(api->GetTensorShapeElementCount(shape, &actual));
    require(count == actual, "Runtime output storage and shape disagree.");
    ONNXTensorElementDataType element;
    owner->library->check(api->GetTensorElementType(shape, &element));
    require(element == owner->outputs[i].element, "Runtime output element type changed.");
    void* buffer = nullptr;
    owner->library->check(api->GetTensorMutableData(output_values[i], &buffer));
    cpp11::sexp output;
    if (element == ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32) {
      cpp11::writable::integers storage(count);
      for (size_t j = 0; j < count; ++j) {
        int32_t value = static_cast<int32_t*>(buffer)[j];
        require(value != INT_MIN, "int32 output conflicts with the base R missing-value sentinel.");
        storage[onnx_internal_r_offset(j, dimensions)] = value;
      }
      output = storage;
    } else {
      cpp11::writable::doubles storage(count);
      for (size_t j = 0; j < count; ++j) {
        double value;
        if (element == ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT) value = static_cast<float*>(buffer)[j];
        else if (element == ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE) value = static_cast<double*>(buffer)[j];
        else {
          int64_t integer = static_cast<int64_t*>(buffer)[j];
          require(integer >= -9007199254740992LL && integer <= 9007199254740992LL,
            "int64 output outside +/-2^53 has no exact base R representation.");
          value = double(integer);
        }
        storage[onnx_internal_r_offset(j, dimensions)] = value;
      }
      output = storage;
    }
    if (rank > 0) {
      cpp11::writable::integers dims(rank);
      for (size_t j = 0; j < rank; ++j) dims[j] = int(dimensions[j]);
      output.attr("dim") = dims;
    }
    result[i] = output;
    names[i] = owner->outputs[i].name;
  }
  result.names() = names;
  return result;
}
