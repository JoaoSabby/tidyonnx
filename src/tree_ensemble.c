/* Pure C17 traversal: no allocation, R API calls, or exceptions in worker threads. */
#include "tidyonnx_api.h"
#include <math.h>
#include <limits.h>
#ifdef _OPENMP
#include <omp.h>
#endif

int tidyonnx_has_openmp(void) {
#ifdef _OPENMP
  return 1;
#else
  return 0;
#endif
}

/* Stable sigmoid preserves extreme margins and missing-value routing semantics. */
static float logistic(float margin) {
  if (margin >= 0.0f) return 1.0f / (1.0f + expf(-margin));
  float exponential = expf(margin);
  return exponential / (1.0f + exponential);
}

/* Each row visits trees in a fixed order, independent of the worker count. */
void tidyonnx_predict(const TidyOnnxEnsemble* model,
    const TidyOnnxColumn* columns, size_t num_rows, double* output, int threads,
    float* workspace) {
#ifndef _OPENMP
  (void)threads;
#endif
#ifdef _OPENMP
#pragma omp parallel num_threads(threads) if(num_rows > 128)
#endif
  {
    int worker = 0;
#ifdef _OPENMP
    worker = omp_get_thread_num();
#endif
    /* Workspace is allocated before entering OpenMP; workers own disjoint slices. */
    float* scores = workspace + (size_t)worker * (size_t)model->num_targets;
#ifdef _OPENMP
#pragma omp for schedule(static)
#endif
    for (size_t row = 0; row < num_rows; ++row) {
      for (int target = 0; target < model->num_targets; ++target) scores[target] = 0.0f;
      for (size_t tree = 0; tree < model->num_trees; ++tree) {
        const TidyOnnxNode* node = model->nodes + model->roots[tree];
        while (node->mode != 0) {
          const TidyOnnxColumn* column = columns + node->feature;
          size_t offset = row * column->stride;
          float value;
          if (column->integer) {
            int integer_value = ((const int*)column->data)[offset];
            value = integer_value == INT_MIN ? NAN : (float)integer_value;
          } else {
            value = (float)((const double*)column->data)[offset];
          }
          int take_true;
          if (isnan(value)) {
            take_true = node->missing_true;
          } else {
            /* Modes mirror ONNX-ML's six numerical branch comparisons. */
            switch (node->mode) {
              case 1: take_true = value < node->threshold; break;
              case 2: take_true = value <= node->threshold; break;
              case 3: take_true = value > node->threshold; break;
              case 4: take_true = value >= node->threshold; break;
              case 5: take_true = value == node->threshold; break;
              default: take_true = value != node->threshold; break;
            }
          }
          node = model->nodes + (take_true ? node->true_child : node->false_child);
        }
        for (size_t index = node->weight_start;
            index < node->weight_start + node->weight_count; ++index) {
          const TidyOnnxWeight* weight = model->weights + index;
          scores[weight->target] += weight->value;
        }
      }
      /* ONNX adds base values after the tree sum; classifier intercepts use a stump. */
      for (int target = 0; target < model->num_targets; ++target) {
        scores[target] += model->base_values[target];
      }
      if (model->transform == 1) {
        for (int target = 0; target < model->num_targets; ++target) {
          scores[target] = logistic(scores[target]);
        }
      } else if (model->transform == 2) {
        float maximum = scores[0];
        for (int target = 1; target < model->num_targets; ++target) {
          if (scores[target] > maximum) maximum = scores[target];
        }
        float denominator = 0.0f;
        for (int target = 0; target < model->num_targets; ++target) {
          scores[target] = expf(scores[target] - maximum);
          denominator += scores[target];
        }
        for (int target = 0; target < model->num_targets; ++target) {
          scores[target] /= denominator;
        }
      }
      for (int target = 0; target < model->num_targets; ++target) {
        output[row + (size_t)target * num_rows] = (double)scores[target];
      }
    }
  }
}
