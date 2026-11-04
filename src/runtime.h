// Sessions retain shared library ownership until every dependent C resource is released.
#ifndef TIDYONNX_RUNTIME_H
#define TIDYONNX_RUNTIME_H
#ifdef _WIN32
#include <windows.h>
// MinGW's SAL spellings differ from the portable annotations in the official header.
#ifdef __MINGW32__
#undef _Check_return_
#undef _In_reads_
#undef _In_reads_opt_
#undef _Inout_updates_
#undef _Out_writes_
#undef _Out_writes_opt_
#undef _Inout_updates_all_
#undef _Out_writes_bytes_all_
#undef _Out_writes_all_
#undef _Success_
#undef _Outptr_result_buffer_maybenull_
#endif
#if defined(__MINGW32__) && !defined(_stdcall)
#define _stdcall __stdcall
#endif
#if defined(__MINGW32__) && !defined(_Frees_ptr_opt_)
#define _Frees_ptr_opt_
#endif
#endif
#include "ort_include/onnxruntime_c_api.h"
#include <cpp11.hpp>
#include <memory>
#include <string>
#include <vector>

namespace tidyonnx {
struct RuntimeLibrary {
  void* handle = nullptr;
  const OrtApi* api = nullptr;
  OrtEnv* environment = nullptr;
  std::string version;
  // Load the exact private path and reject a different release or incompatible ABI.
  explicit RuntimeLibrary(const std::string& path);
  // Environment destruction precedes unloading the library that owns its code.
  ~RuntimeLibrary();
  // Status objects are released before their diagnostic becomes a C++ exception.
  void check(OrtStatus* status) const;
};
struct TensorMetadata {
  std::string name;
  ONNXType kind = ONNX_TYPE_UNKNOWN;
  ONNXTensorElementDataType element = ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED;
  std::vector<int64_t> dimensions;
  std::vector<std::string> symbols;
};
struct RuntimeSession {
  std::shared_ptr<RuntimeLibrary> library;
  OrtSession* session = nullptr;
  std::vector<TensorMetadata> inputs;
  std::vector<TensorMetadata> outputs;
  std::vector<std::pair<std::string, std::string>> metadata;
  std::string producer;
  // Construction is committed only after session and tensor metadata are available.
  RuntimeSession(cpp11::raws bytes, cpp11::list params);
  // Shared library ownership survives release of this session and its metadata.
  ~RuntimeSession();
};
// A null or foreign pointer must never reach an ONNX Runtime entry point.
RuntimeSession* onnx_internal_checked_session(SEXP pointer);
}
#endif
