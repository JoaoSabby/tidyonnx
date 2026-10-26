# Validation record

## Version 0.1.1 review, 2026-10-26

`R CMD build` and `R CMD check --no-manual` completed with **Status: OK**,
zero errors, zero warnings, and zero notes. The source archive was checked for
compiled objects, shared libraries, and native symbol caches.

The complete suite passed **192 expectations across 34 tests**, with zero
failures, warnings, errors, or skips. The same suite passed against a separately
installed build with OpenMP disabled, and engine inspection confirmed OpenMP was
unavailable in that build.

The suite covers six source objectives, scalar and vector intercepts, parallel
trees, early stopping and explicit all-iteration export, binary and multiclass
ordering, formula and recipe preprocessing, direct parsnip and workflow
conversion, butcher compatibility, dataframe subclasses, empty batches, native
session restoration, checksummed backing files, staged publication, malformed
wire data, graph topology, signed labels, declared attribute types, and float32
input bounds.

All modeling examples in the README were executed. A fresh R process predicted
from serialized native and workflow objects without loading the source engine
namespace. Code and documentation coverage audits passed for all 33 named
package R functions.

The current validation environment was Linux x86-64, R 4.3.3, XGBoost 3.2.1.1,
S7 0.2.2, cpp11 0.5.5, parsnip 1.6.1, workflows 1.3.0, recipes 1.4.0, modeldata
1.6.0, and butcher 0.4.0. This exercises the declared minimum R version.

## Independent runtime comparison

The final graphs were executed through the official Linux x64 ONNX Runtime
1.20.1 C API by `tools/validate-runtime.cpp`. This reference library is an
independent development check and is not an installed package dependency.

Twelve deterministic scenarios used 500 rows, five numerical features, missing
values, and 25 boosting iterations. They covered all six objectives, nondefault
and automatically estimated intercepts, an all-positive binary dataset, and
softmax models with two and three classes.

| Comparison | Largest absolute difference |
| --- | ---: |
| tidyonnx vs XGBoost | 9.5367431640625e-7 |
| tidyonnx vs ONNX Runtime | 1.1920928955078125e-7 |
| XGBoost vs ONNX Runtime | 9.5367431640625e-7 |

All scenarios passed the 5e-6 absolute acceptance threshold. For multi:softmax,
reference probabilities were reconstructed from output margins before comparison.
Detailed results are in `tools/evidence/review-runtime-equivalence.csv`.

## Performance evidence

The 800-tree conversion benchmark observed median times of 0.188 s before the
review and 0.134 s after it, a 28.7% reduction over seven repetitions. Prediction
error was unchanged between revisions. The longer regression fixture used an
explicit scale-adjusted float32 bound. See [REVIEW.md](REVIEW.md) and
`tools/evidence/review-benchmark.csv` for the setup and numerical measurements.
No production inference speedup or specialized-hardware result is claimed.

## Cross-platform automation and historical evidence

The repository workflow checks Linux, Windows, and macOS and runs the source
coverage audit before package checks. Current branch run results are available
in [GitHub Actions](https://github.com/JoaoSabby/tidyonnx/actions).

The earlier version 0.1.0 validation on 2026-10-24 reported 148 passing
expectations and independent Windows x64 ONNX Runtime comparisons. Its retained
files `tools/evidence/R-CMD-check.log`, `github-actions.json`,
`runtime-equivalence.csv`, and `test-results-no-openmp.csv` are historical
records. The prior cross-platform code commit was
`d1f69e6f25812a0adab6f0fa22136114b34dc10e`, with
[workflow run 40150212389](https://github.com/JoaoSabby/tidyonnx/actions/runs/40150212389).
The new review evidence uses the `review-` filename prefix.
