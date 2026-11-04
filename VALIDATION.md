# Current reference: Fedora Docker with Intel and supplied Makevars

As of 2026-11-04, the reference is the latest stable Fedora and latest stable
CRAN R, compiled with Intel oneAPI using the supplied Makevars.001 profile.
GitHub Actions runs all package validation inside that Docker container.
ONNX Runtime remains the official precompiled 1.31.1 CPU release.

The unchanged profile is tools/docker/reference/Makevars.001. SHA-256:
998a06d9f8531fe4179b8bfe993f8b29529cd441d0e6073d48dbdfa7161c74a0.
The adapter resolves container paths and the C17 compiler hook, and maps the
ifx full-LTO flag to its equivalent flag-only spelling. R's shared-library link
retains its required libR dependency explicitly during as-needed/LTO resolution. The original
Cascade Lake/AVX-512, fast arithmetic, FMA, flush-to-zero, LTO and OpenMP settings
are preserved. There is no automatic compiler or architecture fallback.

**Intel execution status: R shared-library linkage failed on a compatible CPU.**
The final tested configuration is commit
24d4b04c364eeef8f193574b861a769550a2b735 on test/fedora-docker-20261104.
The latest run is https://github.com/JoaoSabby/tidyonnx/actions/runs/41787360480.

| Run | Host label | Exact observed result |
| --- | --- | --- |
| 41786051570 | ubuntu-latest (Ubuntu 26.04) | Fedora 45 and signed Intel compiler packages 2026.2.0-863 installed; the CPU guard rejected missing AVX-512/VNNI before R compilation and package tests. |
| 41786900653 | ubuntu-24.04 | Fedora 45 CPU preflight found AMD EPYC 7763; avx512f absent; image construction stopped before toolchain installation. |
| 41787092093 | ubuntu-22.04 | The same EPYC 7763 and missing avx512f blocked the container preflight. |
| 41787360480 | ubuntu-24.04 | Runner-selection configuration reproduced the same hardware block. |
| 41787778315 | ubuntu-24.04 | Intel Xeon Platinum 8370C passed CPU checks and the AVX-512 VNNI execution probe. R 4.6.2 compilation reached linking, then R.bin failed to resolve three required libR exports. |

All five runs ended with workflow failure; their artifact-upload steps succeeded.
The compatible run used Fedora 45, Intel compilers 2026.2.0 and MKL. A correction
using R's supported LTO configuration and explicit retention of the required
R library is prepared for the next run. No successful R or package result is claimed.
No Intel package installation, testthat case, independent prediction comparison,
benchmark or R CMD check completed. Those acceptance phases remain blocked.
The R 4.6.2 source build with this Intel profile has not completed successfully.
The supplied profile hash was preserved and checked; its arithmetic settings
were not relaxed. Existing numerical tolerances, missing-value tests and the
strict package-check gate remain unchanged. The two known Rd warnings are not waived.

The repository has zero registered self-hosted runners (queried through the
authenticated GitHub API). Standard host labels do not guarantee the required ISA.
To resume, provide an existing GitHub runner exposing all required CPU features,
select its label through the workflow runner input, or set repository variable
TIDYONNX_REFERENCE_RUNNER for push/PR runs. No paid runner or external server
was provisioned, and no emulated execution was counted as reference evidence.

The final artifact is fedora-intel-validation, ID 13301787294, SHA-256
87c1c15b0d6c9bae6f73dbe961940a809433ef0e833fdd8fc1ec92febdfde892.
Artifacts from the five Intel attempts were downloaded locally and their
published SHA-256 values verified under validation-results/fedora-github/.
Only static R/shell syntax, source policy review and Git whitespace checks were
performed on Windows during this transition; these are not package test results.

The earlier GCC preparation run 41783842103 compiled R 4.6.2 on Fedora 45 but
stopped at the installed-version probe before package tests. The bootstrap R
environment isolation was corrected for the following run, 41785046999. That
auxiliary GCC execution was cancelled after the reference changed to Intel;
it has no accepted result and cannot approve the Intel reference.

Each launch resolves official latest stable release metadata. Logs and provenance
are retained in validation-results/fedora/<run-id>/ and GitHub Actions artifacts.
See tools/docker/README.md for commands, compiler scope and evidence contents.

The following record describes the earlier Windows implementation at 2d894b7.
Its results are historical and do not validate the Intel Docker configuration.

---

# Validation record for 0.2.0

Validated on PC-TOHP2 on 2026-11-03 (America/Sao_Paulo).
The implementation source was the existing checkout at
C:/Users/tohpd_47jrva3/OneDrive - UGent/John Research/Dev/tidyonnx.
Baseline: main, d8a77cbf6bfe681fa43760e69e1e882053bed546,
origin https://github.com/JoaoSabby/tidyonnx.git. No checkout replacement,
reset, push, merge, publication or release was performed.

## Current executed results

- Baseline suite before edits: 148 passing expectations.
- Changed package: **280 passing expectations in 43 test cases**, zero failures,
  errors, warnings or skips.
- Normal staged source installation: **DONE**, including fixed-release download,
  archive verification, compilation and temporary/final load checks.
- `R CMD build --no-build-vignettes --no-manual .`: successful source build.
  On this Windows filesystem the build corrected execute permissions for
  configure and cleanup in the archive and reported those two corrections.
- `R CMD check --no-manual --no-build-vignettes`: **0 errors, 2 warnings, 0 notes**;
  process exit status 0. All package tests passed.
- Fresh process: inference without loading the optional XGBoost namespace,
  RDS restoration, bytecode disassembly, namespace unload/reload and GC passed.
- An actual embedded RDS created by installed tidyonnx 0.1.0 migrated and
  predicted with maximum absolute difference 8.19563865661621e-8 from baseline.
- Authored-source text, comment ASCII/90-column and source-archive gates passed.
  The source archive contains no runtime binaries, downloaded SDK headers or
  build objects. No Rd file changed and no documentation generator ran.

The two package-check warnings are deliberately unresolved in this phase:
missing Rd entries for add_onnx, extract_fit_onnx and onnx_run; and the new
onnx_convert target_name argument missing from the existing Rd signature.
The README documents the new API. Existing Rd files remain unchanged as requested.
The existing remote CI treats warnings as failures; no remote CI run was started.

Tested source archive: tidyonnx_0.2.0.tar.gz, SHA-256
`e40b3735f318b46e66a27348ef34ed3f2d1f8243088b6e5ddb8ddafc4fa9b57c`.
This archive identifies the tested package sources; development evidence and
this report are excluded by the existing source-build rules.

## Runtime and host

- Windows 10 x64 build 19045; R 4.6.0 (2026-04-24 ucrt).
- GCC/G++ 14.3.0; C17 and C++17; cpp11 0.5.5; S7 0.2.2;
  XGBoost 3.2.1.1; workflows 1.3.0; parsnip 1.6.0; recipes 1.3.2.
- ONNX Runtime **1.31.1**, C API **31**, CPU, official Windows x64 asset.
- Archive: onnxruntime-win-x64-1.31.1.zip, 82,929,944 bytes.
- Archive SHA-256:
  `5869e26bb25314375f2d5ef1877e3ea06b1543d6c710e6e4a1ec2f7177ab4b2c`.
- Installed main DLL SHA-256:
  `cb2fa518b18356617f6f9f460c012501da2819ec7e5c1d80bd8f5de20492db0c`.
- All six manifest asset names, URLs and digests matched the fixed official
  Microsoft release metadata. Only Windows x64 installation/loading ran here.
- Package-owned compile commands end in -O3 after configured R flags. Explicit
  portable object rules preserve those flags; no unsafe numeric flags are added.
  Third-party Nanopb compilation retains the ordinary R toolchain settings.

The install/test process restricted PATH to R, Rtools and Windows system
utilities and verified the excluded interpreter was absent from PATH. This is
not a claim that the interpreter is uninstalled from the host. Import tables
for the package DLL, main runtime DLL and provider DLL contain no dependency
on it. The official runtime DLL does contain six incidental ASCII word matches;
its upstream binary text was not altered. Required upstream license and notices
were retained. Authored source is audited separately from those third-party files
and the unchanged, pre-existing handoff reference documents.

Two earlier install attempts targeting a library under the synced project
folder failed with access denied during final directory promotion. Normal
staged installation in R's isolated temporary library passed. A non-staged
local artifact installation also passed. Package source work remained in the
requested checkout; temporary install/check directories were ordinary R outputs.

## Independent execution and numerical evidence

A separately compiled C++ executable loaded the private official DLL through
OrtGetApiBase, created CPU sessions and consumed saved ONNX files without R.
Twelve deterministic scenarios used 500 rows, five features, missing values
and 25 boosting rounds. They covered all six objectives, non-default and
automatic intercepts, all-positive binary training, and two-class softmax.

| Comparison | Largest absolute difference |
| --- | ---: |
| Current tidyonnx vs XGBoost | 1.43051147460938e-6 |
| Current tidyonnx vs independent C API execution | 9.5367431640625e-7 |
| XGBoost vs independent C API execution | 9.5367431640625e-7 |

All scenarios passed the 5e-6 threshold. In-process and standalone sessions use
different thread configurations, so tiny accumulation differences are expected.
Against saved 0.1.0 predictions for 15/300-round binary models, the largest
absolute differences were 8.19563865661621e-8 and 8.49831849336624e-8.

An exact binary probability tie of 0.5 exposes graph label ID 0. The retained
tidy decision selects the positive class. A dedicated compatibility test covers
this difference; onnx_run preserves the actual graph label and never replaces
it with the tidy decision. Non-tie binary labels agree in the tested contract.

## Measurements

These are local observations, not performance guarantees. Single-row timing
averages 100 calls; large batches average three calls, with one configured
intra-op worker. Models have four features and 15 or 300 boosting rounds.

| Rounds | Rows | Former evaluator seconds/call | Runtime seconds/call |
| --- | ---: | ---: | ---: |
| 15 | 1 | 0.00030 | 0.00160 |
| 15 | 100000 | 0.12333 | 0.22333 |
| 300 | 1 | 0.00050 | 0.00140 |
| 300 | 100000 | 1.08333 | 1.24333 |

Conversion elapsed times were 0.01/0.14 seconds before and 0.02/0.10 seconds
currently for 15/300 rounds. Rprofmem recorded 44,872/568,632 allocated R bytes
before and 64,760/568,848 currently. Timer resolution and single conversion
samples limit interpretation. These allocations exclude native allocator and
runtime peak memory. The new mapping explicitly materializes a contiguous input
tensor; no latency or total-memory improvement is claimed.

## Commands and local evidence

Commands ran from the exact checkout, using
C:/Program Files/R/R-4.6.0/bin/R.exe and Rscript.exe, with LC_ALL=C.

```text
Rscript --vanilla validation-results/2026-11-03/baseline.R
R CMD build --no-build-vignettes --no-manual .
Rscript --vanilla tools/validate_local.R
Rscript --vanilla tools/validate_check.R
Rscript --vanilla tools/validate_policy.R
g++ -std=c++17 -O3 -I src/ort_include tools/validate_runtime.cpp -o validation-results/2026-11-03/validate_runtime.exe
```

The local runner executes `R CMD INSTALL --preclean --no-multiarch` into an
isolated temporary library, the full focused suite, benchmark comparisons,
the standalone validation driver and the fresh-session checks. The check runner
executes `R CMD check --no-manual --no-build-vignettes` on the source archive,
using a temporary output directory, and copies its logs back into the checkout.

Evidence is retained under validation-results/2026-11-03, including:
install-final.log, test-final.log, test-results.csv, build.log, 00check.log,
00install.out, testthat.Rout, restricted-path.txt, fresh-process.log, policy.log,
manifest-verification.csv, runtime-dependencies.txt, provider-dependencies.txt,
package-dependencies.txt, independent/runtime-equivalence.csv,
baseline-benchmarks.csv, current-benchmarks.csv, legacy-check.log and tie-decision.csv.

## Acceptance boundaries and checklist

[Every original checklist item](IMPLEMENTATION_CHECKLIST.md) is marked individually:
**83 completed, 5 blocked, 1 not applicable**.

Blocked gates are binary inspection on other architectures, the exact remote
installation on Oracle Linux 9.8 x64, macOS arm64 installation/loading, new
cross-platform CI, and execution on a host with the excluded interpreter
physically uninstalled. Windows x64 and the restricted-PATH case passed.
No support or test success on an unavailable host is inferred.

An additional exploratory Unicode-name formula probe under LC_CTYPE=C failed
in hardhat::mold before conversion, with three terms.formula encoding warnings.
The same probe failed for an ordinary workflow without add_onnx. This locale
boundary is not claimed supported; it is separate from the 280-expectation suite.
Direct XGBoost conversion with UTF-8 feature/class metadata under C did pass.
Both exploratory logs are retained as workflow-utf8.log and workflow-utf8-ordinary.log.

The old package OpenMP gate is not applicable because that evaluator was
removed; ONNX Runtime owns threading. Total runtime workspace memory is not
bounded by the per-tensor R mapping guard. Unsupported ONNX value categories
and unresolved data-dependent output shapes fail explicitly. Legacy file-backed
RDS artifacts have no source digest and require explicit reload; current
file-backed artifacts detect changed files, including same-schema replacements.
No tuning, resampling, recipe export, general R-model conversion, arbitrary
ONNX mapping, GPU support, release or publication is claimed.

The pre-existing IMPLEMENTATION_SPEC.md, STYLE_GUIDE.md and tidyonnx.Rproj
remain byte-identical and untracked. The user's original Rbuildignore lines
remain local; implementation exclusions are staged separately for the commit.

## Historical 0.1.0 record

The following record predates this implementation and is not evidence that
0.2.0 passes those remote platforms.

# Validation record

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
No Intel oneAPI, AVX-512, GPU, large-model performance benchmark, exhaustive
fuzzing, or general ONNX conformance result is claimed. No CRAN submission has been made.
