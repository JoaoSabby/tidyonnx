# tidyonnx

Native ONNX serialization and CPU inference for numerical XGBoost tree models.
The public interface uses S7 objects and returns tibbles.

```r
library(tidyonnx)

onnx_save(fitted_model, "model.onnx")
model <- onnx_load("model.onnx")
onnx_predict(model, new_data)
```

Or convert directly in memory:

```r
fitted_model |>
  onnx_convert() |>
  onnx_predict(new_data, type = "prob")
```

## Installation

Install R 4.3 or newer and a matching R development toolchain (Rtools on Windows).
Then install from source:

```r
install.packages(c("S7", "tibble", "jsonlite", "cpp11"))
install.packages("tidyonnx_0.1.0.tar.gz", repos = NULL, type = "source")
```

Alternatively, install the repository with
`remotes::install_github("JoaoSabby/tidyonnx")`.
XGBoost is required only when converting a fitted `xgb.Booster`.
Prediction and ONNX loading do not require it. Installation performs no downloads.
Nanopb sources are included; neither a schema compiler nor an external inference
library is required.

## Model coverage

| XGBoost objective | ONNX operator | Prediction |
| --- | --- | --- |
| binary:logistic | TreeEnsembleClassifier | Two class probabilities |
| binary:logitraw | TreeEnsembleRegressor | Raw margin |
| reg:squarederror | TreeEnsembleRegressor | Numeric response |
| reg:logistic | TreeEnsembleRegressor + Sigmoid | Logistic response |
| multi:softprob | TreeEnsembleClassifier | Class probabilities |
| multi:softmax | TreeEnsembleClassifier | Class probabilities or argmax class |

Conversion uses the stable XGBoost JSON model representation, including its
tree-to-class assignments and scalar or vector intercept. It exports **all stored
trees**, rather than a caller-specific iteration range. Numerical `gbtree`
boosters and `num_parallel_tree` are supported. Categorical splits, DART,
linear boosters, vector leaves, and multiple regression targets are rejected.
Custom objectives cannot be reconstructed from a saved model; only the six
stored built-in objective names above are supported.

## Predictions

```r
onnx_predict(model, new_data)                   # Probabilities, or numeric regression
onnx_predict(model, new_data, type = "class")   # Factor .pred_class
onnx_predict(model, new_data, type = "numeric") # Numeric .pred; binary positive probability
onnx_predict(model, new_data, type = "raw")     # Numeric vector or probability matrix
predict(model, new_data)                       # stats::predict() compatibility
onnx_inspect(model)                            # Tables of graph and engine details
```

Probability columns are named `.pred_0`, `.pred_1`, or `.pred_{level}`.
Custom labels can be supplied with
`params = list(class_levels = c("absence", "presence"))` at conversion.
Multiclass models reject `type = "numeric"` because one numeric response is
ambiguous. `type = "raw"` describes the unformatted output; it does **not** request
a pre-activation margin.

Named input columns are aligned to the saved feature order. Extra data-frame
columns are ignored. Unnamed matrices use their column order. Integer and double
columns are read directly; missing values follow each tree's learned direction.
Factors, strings, dates, list columns, infinite values, missing predictors,
duplicate names, and incorrect matrix widths fail explicitly. Preprocessing and
factor encoding must match training. Empty batches return zero-row outputs.

## Persistence and threads

`onnx_save()` returns the normalized destination path invisibly.
`onnx_convert()` embeds bytes and creates no temporary ONNX file.
`onnx_load()` embeds bytes by default, so models restored with `readRDS()`
automatically rebuild their native session even if the original ONNX file was
removed. Use `params = list(embed_raw_bytes = FALSE)` on load for file-backed
restoration; the file must remain available. Replacing a backing file with another
model with the same schema changes its future restored predictions.

`params = list(intra_op_threads = 4L)` limits each inference call to at most four
OpenMP workers. The default `0L` uses the physical-core count reported by R,
falling back to one if unknown. Small batches run serially. Threads do not change
the order of tree accumulation. No global OpenMP settings are modified.
Builds without OpenMP execute serially; inspect
`onnx_inspect(model)$engine$openmp` to see actual availability.

## Runtime scope and tuning

This version implements the attachment's **Route A**: a self-contained C17
tree evaluator, a C++17 cpp11 ownership bridge, and Nanopb wire encoding/decoding.
It provides CPU inference, not GPU execution or a general neural-network runtime.

External ONNX loading accepts one numerical `ai.onnx.ml` TreeEnsembleClassifier
or TreeEnsembleRegressor node, optionally followed by a standard Sigmoid for regression, one float32 input of shape `[N, P]` with dynamic
rows and known width, SUM aggregation, and supported numerical comparisons.
IR versions 3 through 10 and ML opsets 1 through 3 are accepted within that
subset. Single-score binary classifiers, tensor-valued attributes, nonzero
two-class `base_values`, multi-output regression, ZipMap, preprocessing,
initializers, and arbitrary graph pipelines are rejected instead of being
silently approximated. External models without feature metadata use
`f0`, `f1`, ... . Converted classifiers use explicit scores and a constant
intercept tree for portable runtime semantics.

All public functions accept `params = list()`. Supported settings are:

| Parameter | Default | Route A behavior |
| --- | --- | --- |
| target_opset | 18L | Standard domain version written at conversion; 18–21 |
| ir_version | 8L | Model IR version written at conversion; 8–10 |
| float_precision | "float32" | Only float32 serialization and comparisons |
| embed_raw_bytes | TRUE | Controls embedding for file loads; in-memory objects always embed |
| class_levels | NULL | Defaults to "0", "1", ... from model class count |
| execution_provider | "cpu" | CPU only |
| intra_op_threads | 0L | Maximum OpenMP workers; zero detects physical cores |
| inter_op_threads | 1L | Single graph node; other values rejected |
| graph_opt_level | "all" | "all" or "disable"; no graph rewrites in this engine |
| log_severity | "error" | Validated compatibility setting; this engine reports errors only |

Serialization settings apply to conversion; runtime thread settings apply to each
prediction. Load and inspect do not convert models. Unsupported values and unknown
parameter names fail explicitly. The parameter list is validated per call rather
than retained as a mutable process-wide setting.

## Development and validation

Documentation is maintained directly in `man/`; this version has no roxygen or
Doxygen generation blocks. Run:

```r
cpp11::cpp_register(".")
testthat::test_local()
```

Then run `R CMD build .` and `R CMD check --no-manual tidyonnx_0.1.0.tar.gz`.
The included cross-platform CI performs package checks, while
`tools/validate-runtime.R` compares outputs with a separately downloaded official
ONNX Runtime through its C API. That reference executable is a development tool
and is never built or loaded by package installation.

See [ARCHITECTURE.md](ARCHITECTURE.md) for specification decisions and
[VALIDATION.md](VALIDATION.md) for measured results and limitations.
