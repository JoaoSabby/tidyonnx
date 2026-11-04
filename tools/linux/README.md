# Fedora binary logistic acceptance test

The GitHub Actions workflow resolves `registry.fedoraproject.org/fedora:latest`
to an immutable digest before building. `base-image.txt`, `os-release.txt`, the
RPM versions, R session information, and the source revision identify the actual
environment. The host runner is Ubuntu; R compilation and prediction run inside
the Fedora container, not on the host.

## Ordered, independent R processes

1. `train-binary-logistic.R` creates a seeded 2,400-row numerical training set,
   trains `binary:logistic`, and writes the XGBoost UBJ model and 1,200 reference
   probabilities before conversion. Missing values, constant rows, and extreme
   finite rows are included. The held-out predictors are also saved.
2. `convert-binary-logistic.R` reloads the persisted XGBoost model, converts it,
   and writes a standalone ONNX file and graph inspection data.
3. `predict-binary-logistic.R` opens that ONNX file in a fresh process. It compares
   one-worker and two-worker results exactly, verifies the probability schema,
   and asserts that XGBoost and tidymodels namespaces were not loaded. It saves
   native probabilities independently of the reference process.
4. `compare-binary-logistic.R` reloads both unrounded RDS vectors and requires
   bitwise equality and identical thresholded classes. Numerical tolerance is
   recorded as diagnostic information only; it cannot make this test pass.

CSV files support manual inspection; RDS files retain the original double values
and are the actual comparison inputs. The summary includes exact match counts,
maximum and mean absolute differences, RMSE, and class agreement. SHA256SUMS
protects the saved data and models against accidental replacement. Failure logs
and partial evidence are uploaded even when the build or comparison fails.

## Numerical correction investigated by this test

The initial local preflight had 271 differing probabilities out of 1,200, all on
negative margins. Its maximum absolute difference was 5.9604644775390625e-08.
The native engine used `expf(margin) / (1 + expf(margin))` on negative margins,
while XGBoost uses reciprocal arithmetic `1 / (1 + expf(-margin))`. These forms
are mathematically equivalent but can round differently in float32.

The native kernel now uses reciprocal arithmetic where the exponential is finite
and retains the stable negative-tail form below -88.7 to avoid overflow. An
additional test checks a representable probability below 1e-42; the correction
does not clamp that tail to an artificial constant or zero. The corrected local
preflight reproduced all 1,200 saved reference probabilities bit for bit without
retraining or replacing the reference predictions.

This deterministic fixture's exact match does not establish universal bitwise
equivalence across every model, compiler, platform, or external ONNX runtime.

## Reproduction

```sh
# Use the recorded base digest for exact environment provenance, or resolve latest again.
docker build -f tools/linux/Dockerfile -t tidyonnx-fedora-validation .
mkdir -p validation-results/linux-binary-logistic
docker run --rm \
  -v "$PWD/validation-results/linux-binary-logistic:/artifacts" \
  tidyonnx-fedora-validation
```

The image installs R and its development toolchain from Fedora. cpp11 and the
current XGBoost R package are built from CRAN. No interpreter bridge or external
inference service participates in conversion or prediction.

## Extended model and compiler matrix

`model-matrix.R` evaluates 48 source scenarios: three seeds, binary/regression
tasks, XGBoost/elastic net families, and direct/parsnip/formula-workflow/recipe-workflow
interfaces. Binary XGBoost conversion requires exact equality of both probability
columns at three batch sizes with one and two workers, followed by RDS restoration.
XGBoost regression and elastic net must emit the implemented-format message and
return NULL; their source predictions are saved, but no ONNX prediction is invented.

The Intel workflow checks actual CPU flags and executes an explicit AVX-512 probe.
It builds the package with icx/icpx, records compile commands and disassembly,
and reruns the same source references under precise and experimental fast-math
configurations. The precise profile uses O3, a Skylake AVX-512 target, high ZMM
usage, strict floating-point semantics, and the source-compatible scalar expf call.
Fast-math results are recorded separately and rejected if they change predictions
or input semantics. A compiled ISA target and a successful probe do not establish
that every tree-traversal operation was vectorized or that a speedup was measured.

```sh
# Run the extended matrix only on a host exposing the required AVX-512 features.
docker build --target matrix -f tools/linux/Dockerfile -t tidyonnx-fedora-matrix .
mkdir -p validation-results/linux-model-matrix
docker run --rm \
  -v "$PWD/validation-results/linux-model-matrix:/artifacts" \
  tidyonnx-fedora-matrix
```

## Native compiler performance comparison

`Makevars.intel-native` adapts the enabled optimization settings of the supplied
Makevars.001 to `-march=native -mtune=native`. The compilation host determines the
instruction set; no Cascade Lake target is fixed. The profile uses generic
oneAPI installation variables and contains no original site configuration.
The user's original file is unchanged.

The adapted profile retains O3, vector-width preference, full LTO, OpenMP,
and the original fast arithmetic controls. Disabled site-specific PGO,
custom LLVM extensions, unrelated Fortran tools, and unused external library
configuration are omitted. The C17/C++17 macros follow this package's declared
standards. It is an adapted native profile, not the original file byte for byte.

The benchmark builds generic GCC O2, Intel native fast, and Intel native strict.
The strict control retains the native target and optimization options but uses
strict arithmetic, the scalar expf call, and disabled contraction/flush-to-zero.
Required acceptance includes the complete package suite and exact reproduction
of the saved XGBoost probabilities under GCC and Intel native strict.
Fast-profile prediction mismatches or package-test failures are recorded as
rejected even if their timings are lower.
A successful workflow therefore does not mean that every arithmetic profile passed.

The default fixture has 16 features, missing values, 32-tree/256-tree binary
models, and batches of 1, 1,000, and 100,000 rows. It measures conversion,
warm-cache graph loading, raw inference, and tibble probability output separately.
Each case has warm-up calls and a GCC-calibrated repeated-call count, reused by
both Intel profiles. Seven samples in each of three independent process blocks
give 21 samples per case/profile. Profile order rotates across blocks. The full
run contains 28 cases and 1,764 timing samples across the three builds.

All samples, medians, IQRs, minima, maxima, numerical checks, effective flags,
detected native target, ISA probe output, and build commands are saved.
The ratio is median GCC seconds / median Intel seconds; values above one favor
Intel. Compilation/installation wall times are separate, with the same two build
jobs and disabled ccache hits. XGBoost and R themselves are not rebuilt.

Training, process startup, explicit collection before each sample, and file
output are outside the API timing. Automatic GC and R-call overhead remain inside.
Full-batch predictions are saved once outside the timed region. The raw
positive-class output is checked against XGBoost; the formatted table
also checks its complementary column. Fixture checksums are verified after timing.
A shared runner can introduce noise; these measurements do not establish a
general compiler ranking or validate another CPU's native target.

```sh
# Compile and execute on the same host so native targets match its actual CPU.
docker build --target performance -f tools/linux/Dockerfile -t tidyonnx-fedora-performance .
mkdir -p validation-results/linux-performance
docker run --rm \
  -v "$PWD/validation-results/linux-performance:/artifacts" \
  tidyonnx-fedora-performance \
  bash tools/linux/run-performance.sh tools/linux/Makevars.intel-native /artifacts/performance
```

The dedicated GitHub workflow uses the native profile by default on
`linux-performance-validation`. It requires AVX-512 hardware, records the
native target detected by icx, and executes an AVX-512 probe. Compile flags and
probe success alone are not evidence of a speedup.
