# Fedora and Intel reference validation

The configured reference target is a Docker container using the latest stable
Fedora release, the latest stable CRAN R release compiled with Intel, and Intel
oneAPI icx, icpx and ifx. GitHub Actions launches the container. Its Ubuntu host
does not execute package validation. ONNX Runtime remains pinned to 1.31.1. Image construction is not yet approved.

## Supplied profile

The unchanged reference is tools/docker/reference/Makevars.001, copied from the
user-supplied file. Its SHA-256 is
998a06d9f8531fe4179b8bfe993f8b29529cd441d0e6073d48dbdfa7161c74a0.

The adapter intel_profile.mk resolves the installed oneAPI compiler, MKL and
TBB directories and explicitly selects Intel for packages requesting C17.
It maps full LTO to the equivalent flag-only spelling; R uses its supported
LTO integration. A shared-library/client probe checks exported functions and
data before R compilation. The reference retains the system linker.
The unsuccessful LLVM-linker workaround was removed; LLVM remains a diagnostic
variant rather than an approved replacement. The profile retains Cascade Lake,
512-bit vectors, fast floating-point arithmetic, FMA, flush-to-zero, full LTO
and Intel OpenMP. Optional controls retain their supplied defaults.
The original file is reference material; its comments are not newly authored
package comments and its fallback suggestions are not executed.

There is no automatic fallback to GCC, a conservative arithmetic profile,
another architecture or an older OS/R release. The latest Fedora is not assumed
to be certified by Intel; actual installation and execution must establish
compatibility. Signed oneAPI packages come from Intel's official DNF repository.
The image verifies CPU feature exposure and executes an AVX-512 VNNI probe
before compiling R. A container cannot supply instructions absent from its host.

R, source dependencies, tidyonnx and the independent C API validator use the
Intel profile. The downloaded Microsoft ONNX Runtime library is the official
precompiled release; this workflow does not rebuild that dependency with Intel.

## Execution

.github/workflows/R-CMD-check.yaml runs on push, pull requests and manual
dispatch. It invokes tools/run_fedora_tests.sh and retains artifacts even
when a phase fails. The testing branch is separate from main. No merge or
package release is performed.

For push/PR execution, repository variable TIDYONNX_REFERENCE_RUNNER can select a
compatible runner label. Manual dispatch accepts the runner input directly.
Several standard Ubuntu hosts tried on 2026-11-04 lacked AVX-512. A later Ubuntu
24.04 assignment exposed an Intel Xeon Platinum 8370C and passed the execution probe.
The host label alone therefore cannot guarantee the required CPU. That compatible
attempt subsequently failed while linking R; see VALIDATION.md for exact evidence.

Each launch resolves stable Fedora from official metadata and builds without
cached layers. Distribution R only bootstraps compilation of the current CRAN
source into /opt/R/latest. Its SHA-256 must match the official R Core release
announcement before extraction. OS and R versions are checked again at run time.

The same suite can use a local or remote Docker Linux engine:

```powershell
pwsh -NoProfile -File tools/run_fedora_tests.ps1
```

```sh
sh tools/run_fedora_tests.sh
```

Source is sent as a build context and evidence is copied through Docker,
without requiring a shared host filesystem. Compatibility R entry points
tools/validate_local.R and tools/validate_check.R delegate to these launchers.

## Validation and evidence

The suite runs source build, normal installation, every testthat case, independent
C API parity scenarios, fresh-process persistence and namespace checks, benchmarks,
native dependency inspection, source policy checks and R CMD check. Installation
and validation use a PATH excluding the prohibited interpreter.

The aggressive arithmetic profile can change numeric results. Existing numerical
tolerances and missing-value tests remain unchanged. A compilation or CPU probe
alone is not acceptance evidence. Independent phases continue after failures;
dependent phases become blocked. Package-check warnings and notes fail the gate.

Artifacts include the exact profile and its hash, evaluated compiler variables,
compiler versions, CPU information, image identity, R source hash, package versions,
per-phase logs, expectation counts, prediction comparisons and benchmarks.
GitHub uploads them as fedora-intel-validation under each Actions run.

Reference approval is blocked. Twelve Intel attempts did not complete any
tidyonnx package test: nine lacked the ISA, two failed R linkage and one
reproduced the shared ABI failure with LLVM. The final isolation matrix did
not run because its three assigned CPUs lacked AVX-512.
See VALIDATION.md and validation_attempts.csv for exact executed results. Earlier Windows
or GCC evidence does not establish success for this reference environment.

## Official sources

- https://fedoraproject.org/releases.json
- https://cran.r-project.org/src/base/
- https://stat.ethz.ch/pipermail/r-announce/
- https://www.intel.com/content/www/us/en/developer/tools/oneapi/oneapi-toolkit-download.html
