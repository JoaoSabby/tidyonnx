# Validation record

## Native compiler performance: completed 2026-11-04 UTC

Run [41760546562](https://github.com/JoaoSabby/tidyonnx/actions/runs/41760546562)
passed at source commit 524e0725b7e70ba46e65e57e0a3afe3d3a6bcc51. This is the
full functional/benchmark revision; the earlier run 41757710800 validated the
initial timing harness without the per-profile package-suite stage.

The actual environment was Fedora Linux 44 stable, R 4.6.1, GCC 16.2.1, and Intel
oneAPI DPC++/C++ Compiler 2026.2.0. The runner exposed four logical CPUs on an
AMD EPYC 9V45. Intel detected `znver5` for `-march=native -mtune=native`.
An AVX-512 intrinsic probe compiled for the native target executed successfully.
The Fedora image digest was
`sha256:cb3bd21415bd82a2fae1a9379f3f972fa8e78d460c9f86101274d13230dd6fd6`.

### Configuration and acceptance

The user's Makevars.001 was adapted to a standalone native profile with generic
oneAPI paths. The original site configuration was not published. A separate local
variant changes its architecture/tuning flags while retaining its other settings.
The benchmark profile retains the enabled C/C++ optimization settings and full
LTO, declares the C17/C++17 macros requested by tidyonnx, and omits inactive
site-specific and unrelated Fortran/library setup. See
`tools/linux/Makevars.intel-native` and its README for the exact adaptation.

All three compiled packages passed **184 expectations**, with no skips, warnings,
or failures in the package suite. The aggressive profile nevertheless failed the
benchmark's stronger exact-probability requirement. The compiler also reported
that explicit fast contraction overrides its fast floating-point preset; the
recorded commands preserve the actual tested combination.

| Profile | Package suite | Exact prediction checks | Maximum difference | Decision |
| --- | --- | --- | --- | --- |
| GCC O2 generic | 184 passed | 72/72 | 0 | Accepted |
| Intel O3 native, aggressive arithmetic | 184 passed | 24/72 | 1.1920928955078125e-07 | Rejected |
| Intel O3 native, strict arithmetic | 184 passed | 72/72 | 0 | Accepted |

The 72 checks per profile comprise 24 unique prediction cases repeated in three
process blocks. Independently reloading the saved full-batch RDS matrices verified
all **400,000 formatted probability values** exactly for GCC and Intel strict.
The aggressive profile changed 37,404 values across 18,702 model-row predictions, summed over the two 100,000-row outputs,
including complete-data rows. No thresholded class changed in this fixture.
The strict control uses `-fp-model=strict -fno-builtin-expf -ffp-contract=off`
while retaining O3, native targeting, vectorization controls, and full LTO.

### Measured times

Each of 28 cases has 21 samples per profile, totaling 1,764 recorded timing
samples. Source models, inputs, and reference probabilities are shared. Seven
samples per case are measured in each of three independent process blocks with
rotating profile order. Each profile uses the same GCC-calibrated call count.
Calibration groups short calls until at least approximately 80 ms; grouping can
overshoot that duration. Explicit collection before samples, model training,
process startup, and file output are outside API timings. Automatic GC and public
R API overhead remain inside. Loading measurements use warm filesystem caches.

The following medians are for **100,000 rows, 256 trees, probability-tibble output**:

| Profile | Build + install, seconds | Prediction, 1 worker, seconds | Prediction, 2 workers, seconds |
| --- | --- | --- | --- |
| GCC O2 generic | 3.638 | 0.711 | 0.461 |
| Intel O3 native, aggressive | 4.454 | 0.747 | 0.523 |
| Intel O3 native, strict | 4.286 | 0.773 | 0.534 |

GCC had the lower medians in this scenario. These observations do not establish
a general compiler ranking or predict performance on the BrotServer Xeon.
A successful ISA probe also does not show that all tree traversal was vectorized.
Raw samples, all 56 Intel/GCC case comparisons, IQRs, minima, and maxima are
tracked in `tools/evidence/native-all-timings.csv` and
`tools/evidence/native-performance-comparison.csv`.

### Evidence

Artifact [13290449302](https://github.com/JoaoSabby/tidyonnx/actions/runs/41760546562/artifacts/13290449302)
contains source models, original and ONNX predictions, inputs, compilation
commands, complete package-test logs, target detection, numerical checks, and
raw timings. The 22,499,875-byte ZIP was downloaded and verified against SHA-256
`5662c19e4c47dca88203215c7377c6d946507b6329a0b9b50fb2770550dd2214`.
All eight fixture checksums were also verified locally. Its local extraction is
`validation-results/native-performance-final`; the GitHub artifact expires
on 2026-11-18. Compact provenance and prediction diagnostics are tracked in
`tools/evidence/native-performance-provenance.json` and
`tools/evidence/native-performance-prediction-audit.csv`.



## Model-matrix revision: 2026-11-03 (America/Sao_Paulo)

The current public scope rejects XGBoost regression conversion and elastic net
conversion with an informative message and invisible NULL. Native loading of
supported existing ONNX regressor graphs is retained.

The local Windows working tree passed 184 package expectations with no failures,
warnings, or skips. Its full package check completed with Status: OK. The expanded
local matrix passed all 48 source scenarios: 12 binary XGBoost conversions with
exact full-probability-table equality and 36 expected unsupported results. It
covers three seeds, direct engines, parsnip, formula workflows, recipe workflows,
three batch sizes, and one-worker/two-worker consistency.

The first completed Fedora binary acceptance run is
[41565220687](https://github.com/JoaoSabby/tidyonnx/actions/runs/41565220687),
at source commit 78c5a8a94e97cda192b8a6c3e4f563d181806e77. Fedora Linux 44,
R 4.6.1, and GCC 16.2.1 produced **1,200 exactly matching probabilities**, maximum
absolute difference zero, and 1,200 matching classes. Reference predictions were
saved before conversion. ONNX inference ran in a fresh process without loading
XGBoost or tidymodels. The downloaded artifact SHA-256 and all 18 file checksums
were verified locally. Its summary is `tools/evidence/fedora-binary-logistic-summary.json`.
Three workflow tests were skipped in that initial minimal image; the expanded
matrix image installs the required adapters explicitly.

The expanded Fedora GCC matrix also passed all 48 scenarios in run
[41570529372](https://github.com/JoaoSabby/tidyonnx/actions/runs/41570529372),
at source commit 4837fecc904d8e89dfa78ea3d20c4074e4e08f20. All 12 supported
conversions matched exactly, with maximum absolute difference zero; the other
36 returned the expected unsupported result. Its full package suite passed
without skips. That run subsequently stopped while initializing Intel because
the container lacked `ps`; it does not validate Intel compilation or inference.
The artifact archive SHA-256 was verified locally.

### Completed Intel AVX-512 matrix

Run [41575169595](https://github.com/JoaoSabby/tidyonnx/actions/runs/41575169595),
attempt 2, passed at source commit c9f013b13d52412a570bb673088e1e9f5ec6ac07.
The actual container was Fedora 44 stable, R 4.6.1, GCC 16.2.1, and Intel oneAPI
DPC++/C++ Compiler 2026.2.0. Its Ubuntu host exposed four logical CPUs on an
AMD EPYC 9V45 processor. This validates the Intel compiler on AVX-512 hardware;
it is not an Intel-CPU benchmark. Fedora's stable latest image resolved to
`sha256:9b53c238bb4e9f6221b4820bbdfa61c1bd8273d386dacaaed429a81dd7362085`.

| Build | Binary scenarios | Unsupported scenarios | Maximum probability difference | Decision |
| --- | --- | --- | --- | --- |
| GCC | 12 exact | 36 expected | 0 | Accepted |
| Intel O3 / AVX-512 / strict arithmetic | 12 exact | 36 expected | 0 | Accepted |
| Intel O3 / AVX-512 / fast-math | 12 mismatches | 36 expected | 1.1920928955078125e-07 | Rejected |

Each accepted profile matched all 14,400 values in the full 600-row, two-column
probability tables. The additional 1-row and 121-row batches matched exactly,
one-worker and two-worker outputs were identical, and RDS restoration preserved
predictions. The complete package suite passed under GCC and Intel strict,
without skips. XGBoost regression and elastic net returned the required message
and NULL through all four interfaces. Their original predictions were saved,
but unsupported conversions have no ONNX predictions to compare.

The accepted Intel profile compiled every C and C++ translation unit using
`icx`/`icpx`, `-O3 -march=skylake-avx512 -qopt-zmm-usage=high`,
`-fp-model=strict -fno-builtin-expf -ffp-contract=off`, and Intel OpenMP.
The compiler's environment required `procps-ng`. R's C17 compiler must be selected
with `CC17`; its flags use a separate variable to avoid R's command-line CFLAGS
mapping. These setup issues were corrected before the successful run.
An explicit AVX-512 intrinsic probe was compiled, its ZMM instructions recorded,
and the executable passed on the actual runner. Disassembly and compile commands
are preserved; no speedup or universal hot-loop vectorization is claimed.

The aggressive experiment changed only the arithmetic profile to
`-fp-model=fast=2 -ffast-math`. Both native builds installed successfully. Its
full probability tables contained 1,404 changed values across 702 of 7,200 rows,
including rows without missing values; no predicted class changed in this fixture.
This rules out missing-data handling as the sole explanation. The combined
fast-math profile permits arithmetic changes, but the separate contribution of
each flag was not isolated. The correction for the required exactness contract
is the accepted strict profile, retaining O3 and AVX-512. The experimental profile
is explicitly rejected and is not configured in the package's default Makevars.
The workflow succeeds only after both required profiles pass; its successful
status does not mean that fast-math passed.

Artifact [13203147867](https://github.com/JoaoSabby/tidyonnx/actions/runs/41575169595/artifacts/13203147867)
contains the original models, inputs, predictions, converted RDS objects,
per-profile predictions, messages, build logs, and assembly. Its downloaded
26,730,996-byte ZIP was verified against SHA-256
`e17df18d6bea172c5bff233b075e2026d594d4ae6cb1588703e229d96ecafbca`.
A local copy is retained in `validation-results/linux-model-matrix-intel`;
the GitHub artifact expires on 2026-11-17. Compact summaries, compiler logs,
CPU details, and fast-math diagnostics are tracked in `tools/evidence`.

These deterministic fixtures establish exact agreement for the tested models
and environments, not a universal bitwise guarantee for every possible model.

## Historical S7 architecture revision: 2026-11-02 (America/Sao_Paulo)

The revision in branch `s7-conversion-architecture` was built and installed with
R 4.6.0 and GCC/G++ 14.3.0 on Windows x64. The updated behavioral suite passed
**182 expectations across 28 tests**, with zero failures, errors, warnings, or
skips. The machine-readable current-run summary is
`tools/evidence/s7-test-results.csv`.

Checks include all six existing XGBoost objectives, S7 public dispatch and private
naming, informative unsupported-source returns, unmodified destinations on failed
recognition, binary workflow event encodings, multiclass recipe preprocessing,
regression formula blueprints, RDS restoration, and ONNX class-order persistence.

`tools/check-policy.R` passed: native-only runtime policy, no executable R for
loops, and orienting comments in R scripts. `tools/validate-direct.R` passed in a
fresh R process: ONNX load and inference did not load xgboost, workflows, parsnip,
hardhat, or recipes.

`R CMD build` succeeded. The final source archive passed
`R CMD check --no-manual`: **Status: OK**, with zero errors, warnings, or notes.
The log is `tools/evidence/s7-R-CMD-check.log`; the tested archive fingerprint is
`tools/evidence/s7-archive-sha256.txt`.

Cross-platform CI, a build without OpenMP, and independent reference-runtime
execution have not been rerun for this revision. Their records below describe
the historical baseline and do not validate these changes.

## Historical baseline

Validated on 2026-10-24 (America/Sao_Paulo).

## Executed checks

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

## Cross-platform CI

GitHub Actions passed on Windows x64, Ubuntu Linux, and macOS ARM64.
The verified code commit is d1f69e6f25812a0adab6f0fa22136114b34dc10e.
[Successful workflow run](https://github.com/JoaoSabby/tidyonnx/actions/runs/40150212389).
Machine-readable job results are in tools/evidence/github-actions.json.

## Independent ONNX Runtime C API comparison

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

## Coverage and boundaries

Tests exercise numerical boundaries at a strict split threshold, learned
missing-value directions, integer and double storage, empty batches,
feature reordering, target-label persistence, file and RDS restoration,
prediction methods, malformed protobuf input, invalid graph topology,
missing node references, out-of-range features, external metadata-free models,
packed and unpacked attributes, and deterministic predictions at 1/2/4
configured worker limits.

The thread tests establish deterministic output under configured limits;
they do not instrument observed worker counts or prove a speedup.
At that historical baseline, no Intel oneAPI, AVX-512, GPU, large-model benchmark, exhaustive
fuzzing, or general ONNX conformance result is claimed. No CRAN submission has been made.

## Historical performance-harness preparation

The performance harness now has dedicated Fedora/GCC/Intel orchestration and
reports compilation/installation wall time separately from public API conversion,
loading, and prediction. Its default run contains 28 cases with 21 samples per
case and profile. The exact external Makevars is required; a missing file stops
the workflow before the build.

The local mechanism smoke test passed 10 cases with resolved timing medians and
exact source probabilities. It used the same installed Windows GCC build under
both profile labels solely to validate the harness. Injected prediction mismatch
and zero-duration inputs were both rejected. R scripts and Bash syntax were
checked; workflow YAML parsed; the native policy audit passed across 72 R files.
`tools/evidence/performance-harness-validation.json` records these checks.

This is not an Intel/GCC speed measurement. Execution using the user's local
configuration at that stage remained pending authorization to publish it to the public
CI repository/artifact. The supplied local configuration was not uploaded.
