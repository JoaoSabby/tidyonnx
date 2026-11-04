/* The isolated serializer validator owns these compact tree structures. */
#ifndef TIDYONNX_TREE_VALIDATION_H
#define TIDYONNX_TREE_VALIDATION_H
#include <stddef.h>

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
#endif
