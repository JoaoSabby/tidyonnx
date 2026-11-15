# Validation record

## Fedora Linux 45 (2026-11-15)

Validation ran in the official Fedora Linux 45 x86_64 container image with
R 4.6.2, GCC/G++ 16.2.1, cpp11 0.5.4, S7 0.2.2, testthat 3.3.2, and
XGBoost 3.2.1.1. DNF provisioned the system packages and CRAN source archives
supplied S7 and XGBoost. The image digest, package versions, compiler macros,
source archive hashes, and dynamic library linkage are recorded in
[environment.txt](tools/evidence/fedora45/environment.txt).

| Package validation | OpenMP enabled | OpenMP disabled |
| --- | --- | --- |
| `R CMD build .` | Passed | Passed |
| `R CMD check --no-manual --no-build-vignettes tidyonnx_0.1.0.tar.gz` | Status: OK | Status: OK |
| Errors / warnings / notes | 0 / 0 / 0 | 0 / 0 / 0 |
| Test expectations passed | 183 | 183 |
| Test failures / errors / warnings / skips | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 |
| `onnx_inspect()` reports OpenMP | TRUE | FALSE |

Both source builds produced the same archive, with no compiled objects or
libraries in it. The serial check used a user Makevars with
`override SHLIB_OPENMP_CFLAGS :=`. The Fedora package paths were ordered with
`/usr/share/R/library` before `/usr/lib64/R/library` in `R_LIBS` so that
isolated namespace checks could discover both noarch and native RPM packages.
The source install logs record GNU C17 and GNU C++17. The handwritten C core
and C++ bridge also compiled with `-std=c17` or `-std=c++17` and
`-Wall -Wextra -Wpedantic -Werror -fopenmp`, with R and cpp11 headers supplied
as system include paths for the C++ compile.

[OpenMP check log](tools/evidence/fedora45/R-CMD-check-openmp.log) |
[Serial check log](tools/evidence/fedora45/R-CMD-check-serial.log) |
[OpenMP test results](tools/evidence/fedora45/test-results-openmp.csv) |
[Serial test results](tools/evidence/fedora45/test-results-serial.csv)

### Independent ONNX Runtime C API comparison

The standalone C++17 validator used headers and the shared library from the
[official ONNX Runtime 1.32.0 Linux x64 CPU release](https://github.com/microsoft/onnxruntime/releases/tag/v1.32.0).
It ran against both tested package installations. Each run covered the same
12 deterministic scenarios and all six supported XGBoost objectives.
The result CSVs were byte-identical.

| Comparison | Maximum absolute difference |
| --- | ---: |
| tidyonnx vs XGBoost | 9.5367431640625e-7 |
| tidyonnx vs ONNX Runtime | 1.19209289550781e-7 |
| XGBoost vs ONNX Runtime | 9.5367431640625e-7 |

All comparisons met the absolute tolerance of 5e-6 in every scenario.

```bash
g++ -std=c++17 -O2 -Wall -Wextra -Wpedantic -fopenmp \
  -I"$ort_dir/include" tools/validate-runtime.cpp -ldl -o validate-runtime
Rscript tools/validate-runtime.R ./validate-runtime \
  "$ort_dir/lib/libonnxruntime.so" validation-results
```

[OpenMP equivalence CSV](tools/evidence/fedora45/runtime-equivalence-openmp.csv) |
[Serial equivalence CSV](tools/evidence/fedora45/runtime-equivalence-serial.csv) |
[Session information](tools/evidence/fedora45/session-info.txt)

## Windows and cross-platform validation (2026-10-24)

### Executed checks

- R CMD build completed successfully.
- R CMD check --no-manual --no-build-vignettes: **Status: OK**,
  zero errors, zero warnings, zero notes.
- Full test suite: **148 expectations passed**, zero failures, errors, warnings,
  or skips.
- A separate source installation with OpenMP disabled passed the same
  **148 expectations** and reported OpenMP unavailable.
- A fresh R process loaded an ONNX model and predicted without loading
  the xgboost namespace.
- Source archive contains no object files or compiled libraries.

Environment: Windows 10 x64, R 4.6.0, GCC/G++ 14.3.0, cpp11 0.5.5,
S7 0.2.2, and XGBoost 3.2.1.1. C source compilation used GNU C17;
the bridge used C++17. OpenMP-enabled and disabled builds were both executed.

### Cross-platform CI

GitHub Actions passed on Windows x64, Ubuntu Linux, and macOS ARM64.
The verified code commit is d1f69e6f25812a0adab6f0fa22136114b34dc10e.
[Successful workflow run](https://github.com/JoaoSabby/tidyonnx/actions/runs/40150212389).
Machine-readable job results are in tools/evidence/github-actions.json.

### Independent ONNX Runtime C API comparison

The exported graphs were executed by the official Windows x64 ONNX Runtime
1.20.1 release, loaded through a separately compiled development executable.
Neither this library nor the executable is required by the installed package.

Twelve deterministic scenarios each used 500 rows, five numerical features,
missing values, 25 boosting rounds, and a fixed seed. They covered all six
objectives, intercepts 0.2 and 0.8, automatically estimated intercepts, an
all-positive binary training set, and two-class and three-class softmax models.

| Comparison | Largest absolute difference across all scenarios |
| --- | ---: |
| tidyonnx vs XGBoost | 9.5367431640625e-7 |
| tidyonnx vs ONNX Runtime | 1.1920928955078125e-7 |
| XGBoost vs ONNX Runtime | 9.5367431640625e-7 |

The acceptance threshold was 5e-6. All scenarios passed.
For multi:softmax, probabilities were independently reconstructed from
XGBoost's output margins; the package's argmax output is tested separately.

Detailed measurements are in
[tools/evidence/runtime-equivalence.csv](tools/evidence/runtime-equivalence.csv).
The standalone checker and reproducible driver are
[tools/validate-runtime.cpp](tools/validate-runtime.cpp) and
[tools/validate-runtime.R](tools/validate-runtime.R).

### Coverage and boundaries

Tests exercise numerical boundaries at a strict split threshold, learned
missing-value directions, integer and double storage, empty batches,
feature reordering, target-label persistence, file and RDS restoration,
prediction methods, malformed protobuf input, invalid graph topology,
missing node references, out-of-range features, external metadata-free models,
packed and unpacked attributes, and deterministic predictions at 1/2/4
configured worker limits.

The thread tests establish deterministic output under configured limits;
they do not instrument observed worker counts or prove a speedup.
No Intel oneAPI, AVX-512, GPU, large-model performance benchmark, exhaustive
fuzzing, or general ONNX conformance result is claimed. No CRAN submission has been made.
