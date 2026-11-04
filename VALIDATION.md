# Current reference: latest Fedora/R Docker with Intel and supplied Makevars

The user-defined reference, as of 2026-11-04, is Docker with the latest stable
Fedora and latest stable CRAN R, compiling with Intel and Makevars.001.
GitHub Actions is the executor. Package tests do not run on the Windows host.
ONNX Runtime stays pinned to the official precompiled 1.31.1 CPU release.

**Reference approval is blocked. No tidyonnx package test completed in the
Intel reference environment.** Configuration is implemented; successful
installation and numerical acceptance have not been established.

## Attempted environment and immutable profile

- Fedora 45 was resolved from official metadata and pulled by numeric tag.
  Per-run image digests are retained in the build logs. The registry image
  changed during these attempts; a single digest is not assumed for all runs.
- CRAN R 4.6.2 source passed the required official-announcement SHA-256 check:
  c297040f6392b1dac6e5c0eb398422cfdaedf540ae2205edb9ad0d10cb10ee00.
  Intel compilation reached linking but did not finish installation.
- Signed Intel compiler packages 2026.2.0-863 and MKL development packages
  2026.2.0-881 installed on compatible runs. Intended drivers are icx, icpx
  and ifx. Actual commands are retained in the build logs.
- tools/docker/reference/Makevars.001 is byte-identical to the supplied
  J:/Projetos/BrotServer/scripts/Makevars.001. SHA-256:
  998a06d9f8531fe4179b8bfe993f8b29529cd441d0e6073d48dbdfa7161c74a0.
  Git blob a1f2fc1b95fd4c5d51661813e81e03645a46574c and .gitattributes
  preserve its original bytes and line endings.
- The adapter resolves oneAPI/MKL/TBB paths, selects Intel for C17 requests
  and spells full LTO as -flto. The original -flto=full spelling produced an
  ifx invalid-argument warning. Flag-only LTO retains full mode. R uses its
  supported --enable-lto integration.
- Cascade Lake/AVX-512, O3, fast arithmetic, FMA, flush-to-zero, full LTO and
  Intel OpenMP remain selected. No conservative arithmetic or architecture
  fallback is accepted. Historical OS/R comments in the supplied file do
  not override the user's current Fedora/R target.

## Exact executed results

Twelve Intel attempts ended with workflow failure: nine lacked AVX-512,
two failed R shared-library linkage, and one reproduced an ABI failure in
a minimal shared-library/client program. All twelve artifact-upload steps
succeeded. Commits, CPUs, stages, artifact IDs and archive SHA-256 values are
recorded in tools/docker/validation_attempts.csv.

| Run | Observed result |
| --- | --- |
| [41786051570](https://github.com/JoaoSabby/tidyonnx/actions/runs/41786051570) | Signed Intel packages installed; the CPU guard rejected missing AVX-512/VNNI. CPU model was not recorded. |
| [41786900653](https://github.com/JoaoSabby/tidyonnx/actions/runs/41786900653) | EPYC 7763 lacked avx512f; Fedora container preflight stopped image construction. |
| [41787092093](https://github.com/JoaoSabby/tidyonnx/actions/runs/41787092093) | EPYC 7763 lacked avx512f; Fedora container preflight stopped image construction. |
| [41787360480](https://github.com/JoaoSabby/tidyonnx/actions/runs/41787360480) | EPYC 7763 lacked avx512f; Fedora container preflight stopped image construction. |
| [41787778315](https://github.com/JoaoSabby/tidyonnx/actions/runs/41787778315) | Xeon Platinum 8370C passed AVX-512 VNNI execution; R.bin failed to resolve three required libR exports. |
| [41789469437](https://github.com/JoaoSabby/tidyonnx/actions/runs/41789469437) | EPYC 7763 lacked avx512f; Fedora container preflight stopped image construction. |
| [41789649630](https://github.com/JoaoSabby/tidyonnx/actions/runs/41789649630) | EPYC 7763 lacked avx512f; Fedora container preflight stopped image construction. |
| [41789766080](https://github.com/JoaoSabby/tidyonnx/actions/runs/41789766080) | Xeon Platinum 8370C passed the execution probe. Supported R LTO integration and explicit retention of libR did not fix linkage. Definitions existed in LLVM objects but were absent from libR. |
| [41791543761](https://github.com/JoaoSabby/tidyonnx/actions/runs/41791543761) | Xeon 6975P-C passed the execution probe. Intel LLVM linkage also failed a minimal shared-library/client test: exported function and data symbols could not be resolved. |
| [41792710248](https://github.com/JoaoSabby/tidyonnx/actions/runs/41792710248) | Final flag-isolation configuration stopped at CPU preflight; the matrix did not execute. |
| [41793007222](https://github.com/JoaoSabby/tidyonnx/actions/runs/41793007222) | Manual diagnostic repeat stopped at CPU preflight; the matrix did not execute. |
| [41793397975](https://github.com/JoaoSabby/tidyonnx/actions/runs/41793397975) | Second manual diagnostic repeat stopped at CPU preflight; the matrix did not execute. |

The final executable configuration is commit
40bfe0561d3f29836df4343f23545de0e13ed72f on test/fedora-docker-20261104.
Its three attempts stopped at CPU preflight. The new flag-isolation matrix
has not executed and cannot yet identify a single offending option.

The R link failures named R_running_as_main_program, Rf_initialize_R and
Rf_mainloop. The minimal test failed for onnx_internal_shared_value and
onnx_internal_shared_probe. These are ABI failures before package validation,
not ONNX numerical comparison results.

The unsuccessful LLVM-linker and explicit-libR-retention workarounds were
removed from the reference. LLVM linkage remains a diagnostic variant.
The matrix also diagnoses visibility, semantic interposition, memory layout
and disabled LTO. Variants are labelled diagnostic and cannot approve a
failed reference profile. No option was removed to manufacture acceptance.

## Blocked validation and retained warnings

Intel R installation, tidyonnx build/install, testthat tests, independent
ONNX Runtime comparisons, workflow conversion, persistence, benchmarks,
native dependency inspection and R CMD check remain blocked. There are no
Intel package pass/fail/skip counts to report. The historical Windows
280-expectation result below is not reference approval.

Current container benchmark tooling compares current tidyonnx with XGBoost.
The previous-evaluator benchmark has not been reproduced in Fedora.
No performance improvement or native peak-memory claim is made.

The compiler warned that -ffp-contract=fast overrides -ffp-model=fast.
No numerical conclusion is inferred from this warning. GitHub warned that
the v4 actions target deprecated Node.js 20 and were executed with Node.js 24.
The two historical Rd warnings remain unresolved and are not waived by the
strict package-check gate. No new R CMD check result was obtained.

At closure, the authenticated GitHub API still listed no self-hosted runners.
Standard host labels do not guarantee AVX-512. Approval requires a stable
compatible executor and a compiler/profile combination passing shared ABI
validation. A compatible label can be selected through the runner workflow
input or repository variable TIDYONNX_REFERENCE_RUNNER. No paid runner,
emulation, main merge or package release was introduced.

All twelve Intel artifacts were downloaded to
validation-results/fedora-github/<run-id>/ and their published SHA-256 values
verified. Latest artifact: 13304660295, SHA-256
9f1e1a30702772419ca8a655b755d1c4e9f828930b11cc21a9d6cc5d7102435f.

Windows work during this transition consisted of editing, static syntax/text
inspection, Git checks and evidence retrieval. Static parsing emitted four
locale-configuration warnings; those are not package test results.

Earlier GCC preparation run 41783842103 compiled R 4.6.2 but failed the
installed-version probe. Bootstrap R environment isolation was corrected
in 41785046999, which was cancelled after the reference changed to Intel.
Neither run provides accepted Intel evidence.

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
