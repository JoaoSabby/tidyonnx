/* The inference ABI contains no R or C++ types and borrows all input storage. */
#ifndef TIDYONNX_API_H
#define TIDYONNX_API_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct {
  int feature;
  int true_child;
  int false_child;
  int mode;
  int missing_true;
  float threshold;
  size_t weight_start;
  size_t weight_count;
} TidyOnnxNode;
typedef struct {
  int target;
  float value;
} TidyOnnxWeight;
typedef struct {
  const void* data;
  size_t stride;
  int integer;
} TidyOnnxColumn;
typedef struct {
  const TidyOnnxNode* nodes;
  const TidyOnnxWeight* weights;
  const int* roots;
  const float* base_values;
  size_t num_trees;
  int num_targets;
  int transform;
} TidyOnnxEnsemble;
/* Output is column-major so the caller can write directly into an R matrix. */
void tidyonnx_predict(const TidyOnnxEnsemble* model,
  const TidyOnnxColumn* columns, size_t num_rows, double* output, int threads,
  float* workspace);
int tidyonnx_has_openmp(void);
#ifdef __cplusplus
}
#endif
#endif
