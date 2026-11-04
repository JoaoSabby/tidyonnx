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

## Performance comparison with the supplied Makevars.001

The performance suite uses the exact file passed to `run-performance.sh`,
defaulting to `../Makevars.001` relative to the repository. It refuses to
substitute a guessed configuration when that file is missing. The original file,
its SHA-256, effective compiler commands, CPU information, package-library paths,
and R sessions are retained with the measurements. Inspect a configuration for
private paths or credentials before publishing it in a public CI artifact.

GCC uses a conventional generic O2/OpenMP build. Both builds use two build jobs; ccache hits are disabled for compilation timing. The original Makevars is retained unchanged. A separate include wrapper maps
its C compiler and optimization flags to the C17 macros requested by this package;
only the language-standard flag changes from GNU C23 to GNU C17. Supported
environment inputs point oneAPI components to their container installation paths.
The wrapper and the evaluated variables are recorded with the results. Both builds use the same Fedora image, installed R dependencies,
XGBoost models, inputs, source references, and explicit one-worker/two-worker
settings. XGBoost itself is not rebuilt for the comparison.

The default fixture has 16 features, missing values, 32-tree/256-tree depth-four
binary models, and batches of 1, 1,000, and 100,000 rows. It times public API
conversion, graph loading, raw inference, and tibble probability output separately.
Each case receives two warm-up calls. GCC calibrates the repeated-call count to
at least approximately 80 milliseconds; Intel reuses that count. Seven samples per case
are collected in each of three independent process blocks, alternating profile
order. Reports contain all 21 samples per case, medians, IQRs, minima, maxima,
and the ratio of median GCC seconds to median Intel seconds. A ratio above one
favors Intel. Compilation/installation wall time is recorded separately.

Training, process startup, explicit garbage collection before each sample, and
file output are outside the public-API timing. Automatic collection and R call
overhead remain inside. Calibration uses elapsed-time clock resolution, so very
short calls are grouped; model loading is warm-cache loading. A shared CI runner
can introduce noise, and the result is not a general compiler ranking.

Every probability batch is compared with its persisted original XGBoost values.
Raw output compares the positive class because its complementary class retains
graph-native float32 arithmetic. A faster profile that changes those values is
rejected: its timings remain diagnostic evidence and the workflow fails. Fixture
checksums are verified after timing. No speedup has been established until this
suite completes using the requested file.

```sh
# Mount the actual configuration read-only; do not replace it with example flags.
docker build --target performance -f tools/linux/Dockerfile -t tidyonnx-fedora-performance .
mkdir -p validation-results/linux-performance
docker run --rm \
  -v "$(realpath ../Makevars.001):/Makevars.001:ro" \
  -v "$PWD/validation-results/linux-performance:/artifacts" \
  tidyonnx-fedora-performance \
  bash tools/linux/run-performance.sh /Makevars.001 /artifacts/performance
```

For GitHub Actions, the dedicated workflow accepts a repository-relative
configuration path. Its push trigger uses `linux-performance-validation`.
The configuration is external to the published suite. The original file must
be supplied before CI can execute; the workflow fails before building if it is
absent. Distribution of a local configuration containing internal server paths
requires the owner's authorization. The scripts record effective GNU Make
variables rather than assuming that descriptive comments match the active flags.
