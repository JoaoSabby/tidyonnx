// Independent ONNX Runtime C API oracle; excluded from package builds.

#ifdef _WIN32
#include <windows.h>
#endif
#if defined(__MINGW32__) && !defined(_stdcall)
#define _stdcall __stdcall
#endif
#if defined(__MINGW32__) && !defined(_Frees_ptr_opt_)
#define _Frees_ptr_opt_
#endif
#include "onnxruntime_c_api.h"
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#endif

struct Runtime {
#ifdef _WIN32
  HMODULE library = nullptr;
#else
  void* library = nullptr;
#endif
  const OrtApi* api = nullptr;
  OrtEnv* environment = nullptr;
  OrtSessionOptions* options = nullptr;
  OrtSession* session = nullptr;
  OrtMemoryInfo* memory = nullptr;
  OrtValue* input = nullptr;
  OrtValue* output = nullptr;
  OrtTensorTypeAndShapeInfo* shape = nullptr;
  ~Runtime() {
    if (api) {
      if (shape) api->ReleaseTensorTypeAndShapeInfo(shape);
      if (output) api->ReleaseValue(output);
      if (input) api->ReleaseValue(input);
      if (memory) api->ReleaseMemoryInfo(memory);
      if (session) api->ReleaseSession(session);
      if (options) api->ReleaseSessionOptions(options);
      if (environment) api->ReleaseEnv(environment);
    }
#ifdef _WIN32
    if (library) FreeLibrary(library);
#else
    if (library) dlclose(library);
#endif
  }
  void check(OrtStatus* status) const {
    if (!status) return;
    std::string message = api->GetErrorMessage(status);
    api->ReleaseStatus(status);
    throw std::runtime_error(message);
  }
};

// Arguments: shared-library, model.onnx, float32-row-major-input, rows, cols, output.
int main(int argc, char** argv) {
  try {
    if (argc != 7) throw std::runtime_error("Expected six runtime validation arguments.");
    Runtime runtime;
#ifdef _WIN32
    runtime.library = LoadLibraryA(argv[1]);
    if (!runtime.library) throw std::runtime_error("Cannot load reference ONNX Runtime library.");
    auto get_base = reinterpret_cast<const OrtApiBase* (ORT_API_CALL*)()>(
      GetProcAddress(runtime.library, "OrtGetApiBase"));
#else
    runtime.library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!runtime.library) throw std::runtime_error(dlerror());
    auto get_base = reinterpret_cast<const OrtApiBase* (*)()>(
      dlsym(runtime.library, "OrtGetApiBase"));
#endif
    if (!get_base) throw std::runtime_error("Reference runtime has no C API entry point.");
    runtime.api = get_base()->GetApi(ORT_API_VERSION);
    if (!runtime.api) throw std::runtime_error("Reference runtime C API version mismatch.");
    const auto* api = runtime.api;
    runtime.check(api->CreateEnv(ORT_LOGGING_LEVEL_ERROR, "tidyonnx-validation", &runtime.environment));
    runtime.check(api->CreateSessionOptions(&runtime.options));
    runtime.check(api->SetIntraOpNumThreads(runtime.options, 1));
    std::ifstream model_file(argv[2], std::ios::binary);
    std::vector<char> model((std::istreambuf_iterator<char>(model_file)), {});
    if (model.empty()) throw std::runtime_error("Empty model input.");
    runtime.check(api->CreateSessionFromArray(runtime.environment, model.data(), model.size(),
      runtime.options, &runtime.session));
    int64_t rows = std::stoll(argv[4]);
    int64_t columns = std::stoll(argv[5]);
    if (rows < 1 || columns < 1) throw std::runtime_error("Invalid reference input dimensions.");
    std::vector<float> input(static_cast<size_t>(rows * columns));
    std::ifstream input_file(argv[3], std::ios::binary);
    input_file.read(reinterpret_cast<char*>(input.data()),
      static_cast<std::streamsize>(input.size() * sizeof(float)));
    if (!input_file) throw std::runtime_error("Incomplete float32 reference input.");
    runtime.check(api->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &runtime.memory));
    int64_t dimensions[] = {rows, columns};
    runtime.check(api->CreateTensorWithDataAsOrtValue(runtime.memory, input.data(),
      input.size() * sizeof(float), dimensions, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &runtime.input));
    OrtAllocator* allocator = nullptr;
    runtime.check(api->GetAllocatorWithDefaultOptions(&allocator));
    char* input_name = nullptr;
    char* output_name = nullptr;
    size_t output_count;
    runtime.check(api->SessionGetOutputCount(runtime.session, &output_count));
    runtime.check(api->SessionGetInputName(runtime.session, 0, allocator, &input_name));
    runtime.check(api->SessionGetOutputName(runtime.session, output_count - 1, allocator, &output_name));
    std::string stored_input(input_name);
    std::string stored_output(output_name);
    allocator->Free(allocator, input_name);
    allocator->Free(allocator, output_name);
    const char* input_names[] = {stored_input.c_str()};
    const char* output_names[] = {stored_output.c_str()};
    const OrtValue* inputs[] = {runtime.input};
    runtime.check(api->Run(runtime.session, nullptr, input_names, inputs, 1,
      output_names, 1, &runtime.output));
    runtime.check(api->GetTensorTypeAndShape(runtime.output, &runtime.shape));
    size_t output_size;
    runtime.check(api->GetTensorShapeElementCount(runtime.shape, &output_size));
    void* output_data = nullptr;
    runtime.check(api->GetTensorMutableData(runtime.output, &output_data));
    std::ofstream output_file(argv[6], std::ios::binary);
    output_file.write(static_cast<const char*>(output_data),
      static_cast<std::streamsize>(output_size * sizeof(float)));
    if (!output_file) throw std::runtime_error("Cannot write reference output.");
    std::cout << get_base()->GetVersionString() << " " << output_size << std::endl;
    return 0;
  } catch (const std::exception& exception) {
    std::cerr << exception.what() << std::endl;
    return 1;
  }
}
