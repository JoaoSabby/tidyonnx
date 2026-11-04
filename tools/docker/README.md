# Fedora Docker validation

All canonical tidyonnx validation runs inside one Docker Linux container with
the latest stable Fedora release and the latest stable CRAN R release. GitHub
Actions is the selected execution host. Its Ubuntu runner launches Docker;
package installation, tests and checks execute inside the Fedora container.
The ONNX Runtime dependency remains pinned to 1.31.1.

## GitHub execution

The workflow .github/workflows/R-CMD-check.yaml runs on push, pull requests and
manual dispatch. It invokes tools/run_fedora_tests.sh and retains artifacts
even if a validation phase fails. The validation branch is separate from main.
No merge or package release is performed by the workflow.

Each launch resolves the current stable Fedora version from official metadata,
pulls registry.fedoraproject.org/fedora:<release>, and builds without cached
layers. The distribution R bootstraps compilation of the latest stable CRAN R
source into /opt/R/latest. The source SHA-256 must match the official R Core
release announcement before extraction and compilation.

A stale image, missing checksum, unavailable metadata or failed download stops
the run explicitly. No older-release or host-execution fallback is allowed.
Both OS and R versions are checked again before the package tests begin.

## Local and remote Docker launchers

Local Docker is optional when GitHub Actions is used. The same suite can be
launched manually from the repository root with a Docker Linux engine:

```powershell
pwsh -NoProfile -File tools/run_fedora_tests.ps1
```

```sh
sh tools/run_fedora_tests.sh
```

The shell launcher requires curl. A configured remote Docker context can also
be used: source is sent as a build context and evidence is copied through Docker,
without assuming a shared host filesystem. Compatibility R entry points
tools/validate_local.R and tools/validate_check.R delegate to these launchers.

## Validation phases

The suite executes source build, normal package installation, every testthat
test, independent C API parity scenarios, fresh-process persistence and namespace
checks, benchmarks, native dependency inspection, source policy gates and
R CMD check. Installation and tests use a command PATH excluding the prohibited
interpreter. The runtime pin and numerical tolerances remain unchanged.

Independent phases continue after a failure. Dependent phases are marked blocked.
Warnings and notes keep the final package-check gate unsuccessful; the existing
two documentation warnings are not waived by the Docker transition.

## Evidence and current status

Evidence is retained under validation-results/fedora/<UTC-run-id>/ and uploaded
as the fedora-validation workflow artifact. It includes image identities,
release/source hashes, configuration snapshots, installed package versions,
compiler details, per-phase logs, expectation counts, timings, native dependencies
and package-check results.

No successful Fedora result is claimed until the actual GitHub run completes.
The earlier Windows 280-expectation result remains historical. Review the current
section of VALIDATION.md and the run artifact for authoritative execution results.

## Official sources

- https://fedoraproject.org/releases.json
- https://cran.r-project.org/src/base/
- https://stat.ethz.ch/pipermail/r-announce/
