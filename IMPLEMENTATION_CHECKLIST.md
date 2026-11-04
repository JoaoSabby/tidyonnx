# Current acceptance checklist

Reference: latest stable Fedora/R Docker, Intel and the supplied Makevars.001.
Assessed on 2026-11-04. Reference approval remains blocked. Completed source
work is distinguished from unexecuted runtime acceptance. Prior Windows
results remain historical evidence in VALIDATION.md.

## Reference transition

| Item | Status | Evidence or limitation |
| --- | --- | --- |
| Preserve original Makevars byte identity. | completed | Source/copy SHA-256 match; Git preserves original line endings. |
| Configure latest Fedora/R, Intel and profile use. | completed | Docker/Actions source committed; full image construction is not established. |
| Verify compatible CPU execution. | completed | AVX-512 VNNI passed on Xeon Platinum 8370C and Xeon 6975P-C. |
| Approve reference shared-library ABI. | blocked | R linkage and a minimal shared-library/client program failed. |
| Execute final flag-isolation matrix. | blocked | Three final attempts lacked AVX-512; no variant result is claimed. |
| Complete R installation and Intel package validation. | blocked | No tidyonnx package test completed in the reference. |
| Retain exact Actions evidence and warnings. | completed | Twelve artifacts retained with verified published SHA-256 values. |
| Rebuild upstream ONNX Runtime with Intel. | not applicable | The contract uses official precompiled 1.31.1 CPU assets. |
| Merge main or publish a release. | not applicable | Changes are confined to review/testing branches. |

## Original checklist under the current reference

All 89 original requirements appear once. Counts: 39 completed,
48 blocked, 2 not applicable. Runtime-dependent requirements stay
blocked even when their source and prior Windows evidence already exist.

| # | Status | Requirement | Evidence or limitation |
| --- | --- | --- | --- |
| 1 | completed | Confirm PC-TOHP2, the exact local folder, repository name, branch, commit, remote, and working-tree status before edits. | PC-TOHP2 and canonical checkout verified; migration began at main 2d894b7. Local review branch: test/fedora-intel-20261104; origin retained. |
| 2 | completed | Preserve pre-existing local changes; do not reset or replace the checkout. | The original two ignore rules and three untracked files remain outside authored commits; all three original file hashes match. |
| 3 | completed | Read DESCRIPTION, NAMESPACE, R, src, tests, CI, and current evidence. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 4 | completed | Record which existing behaviors are preserved and which intentionally change. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 5 | completed | Evolve the existing package instead of replacing it wholesale. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 6 | completed | Keep all changes in the tidyonnx repository; do not touch sbyonnx. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 7 | completed | Do not claim any test passed before executing it on the changed code. | No Intel package pass is claimed. Hardware/ABI results and unexecuted phases are distinguished explicitly. |
| 8 | completed | Pin ONNX Runtime exactly to v1.31.1. | Official ONNX Runtime CPU release stays pinned to 1.31.1 in the manifest and installer. |
| 9 | completed | Store all supported platform asset names, URLs, and SHA-256 values. | The manifest retains all six supported CPU asset names, official URLs and SHA-256 digests. |
| 10 | completed | Confirm each manifest URL points to the official Microsoft release. | Manifest release URLs were checked against official Microsoft release metadata during implementation. |
| 11 | completed | Select assets by OS and CPU architecture, not OS name alone. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 12 | completed | Reject unsupported architectures and missing assets explicitly. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 13 | completed | Do not use releases/latest or a silent fallback to another version. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 14 | blocked | Download the selected archive during install without another language runtime. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 15 | completed | Fail clearly on network, TLS, HTTP, or permission errors. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 16 | completed | Verify SHA-256 before unpacking. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 17 | completed | Reject archive path traversal and unexpected layout. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 18 | blocked | Install required license and notice files. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 19 | blocked | Install native library privately and load only that version. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 20 | blocked | Check header/library API compatibility. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 21 | blocked | Record installed runtime version and hash for diagnostics. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 22 | completed | Verify no package-authored source file contains the prohibited word. | Static authored-text review; canonical container policy execution remains blocked. |
| 23 | blocked | Verify no package install/build/test command invokes its interpreter. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 24 | blocked | Inspect binary dependencies for an interpreter runtime on each platform. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 25 | blocked | Test a client installation with that interpreter absent from PATH. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 26 | blocked | Test the exact remotes::install_github command on Oracle Linux 9.8 x64. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 27 | blocked | Test Windows x64 and macOS arm64 installation and loading. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 28 | completed | Make macOS x86_64 fail clearly under the fixed-release policy. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 29 | completed | Preserve current six XGBoost objective paths or document a justified removal. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 30 | completed | Keep one shared tree parser/serializer for supported objectives. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 31 | blocked | Preserve binary and two-class score semantics in independent runtimes. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 32 | completed | Keep XGBoost native JSON export with raw_format = "json". | Source/setup work is complete; this does not assert a successful Intel package test. |
| 33 | blocked | Validate default feature names and explicit feature_names. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 34 | blocked | Reject duplicate, missing, or wrong-length names. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 35 | blocked | Define and test target_name as metadata rather than guessed class labels. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 36 | completed | Preserve a deliberate route for direct custom class labels. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 37 | blocked | Verify ONNX session creation for every supported converted objective. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 38 | blocked | Compare predictions with XGBoost and the current implementation. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 39 | blocked | Verify external ONNX Runtime independently consumes saved files. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 40 | completed | Update onnx_model invariants for generic session metadata. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 41 | completed | Keep portable bytes or a documented backing-file contract. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 42 | completed | Protect and release native resources on all success and error paths. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 43 | blocked | Restore sessions after readRDS without trusting serialized pointers. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 44 | blocked | Detect changed backing files when restoring a file-backed model. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 45 | blocked | Verify repeated load, save, copy, garbage collection, and unload paths. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 46 | blocked | Preserve exact ONNX file bytes across save/load where intended. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 47 | blocked | Prevent partial replacement of an existing destination on write failure. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 48 | completed | Implement the supported named tensor input contract and reject others. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 49 | blocked | Check input names, element types, shapes, dimensions, and row counts. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 50 | blocked | Handle zero-row batches explicitly where runtime semantics permit. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 51 | blocked | Check allocation limits and integer overflow before native allocation. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 52 | completed | Return named outputs with dimensions and documented R storage types. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 53 | blocked | Release every OrtValue and status object, including on failure. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 54 | completed | Keep onnx_run free of tidy class/probability interpretation. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 55 | blocked | Keep onnx_predict outputs stable for supported tabular models. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 56 | completed | Preserve type = "raw" compatibility or document an approved migration. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 57 | blocked | Verify probabilities, labels, class order, and missing-value routing. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 58 | blocked | Reject unsupported external model output shapes without guessing. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 59 | completed | add_onnx marks an artifact request without changing preprocessing. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 60 | blocked | Direct fit invokes the ordinary workflow fit exactly once. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 61 | blocked | Conversion receives the fitted engine, not the untrained specification. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 62 | blocked | Extract names and levels through public workflow accessors. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 63 | blocked | Validate extracted names and levels against engine and ONNX metadata. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 64 | blocked | Attach a complete S7 ONNX artifact to the fitted workflow. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 65 | blocked | extract_fit_onnx returns the artifact or a clear absence error. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 66 | blocked | Ordinary predict on the fitted workflow remains unchanged. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 67 | blocked | Fail fit clearly if requested conversion fails. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 68 | completed | Add no tuning or resampling integration and make no such claim. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 69 | blocked | Test formulas and simple recipes that produce supported numeric engines. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 70 | blocked | Reject unsupported recipe-to-engine data contracts clearly. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 71 | blocked | Enable R byte compilation and verify it in the installed package. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 72 | completed | Apply -O3 to package-owned native code where supported. | Source/setup work is complete; this does not assert a successful Intel package test. |
| 73 | not applicable | Avoid unsafe floating-point flags and unmeasured optimization claims. | The user's aggressive reference supersedes the earlier strict-arithmetic requirement; no performance gain is claimed. |
| 74 | blocked | Benchmark small and large batches against the previous native evaluator. | The previous-evaluator benchmark is not reproduced in Fedora; current tooling compares current tidyonnx with XGBoost. |
| 75 | blocked | Measure conversion time and memory for small and large XGBoost models. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 76 | completed | Keep public and internal naming consistent with STYLE_GUIDE.md. | Public/internal naming and protocol exceptions are preserved; the migration adds private tool helpers only. |
| 77 | completed | Give every authored function concise formal English ASCII comments. | Authored function comments are formal English; the supplied profile is preserved as unchanged reference material. |
| 78 | completed | Enforce comment width of at most 90 characters. | Authored comment widths were statically reviewed; the canonical container policy gate is blocked. |
| 79 | completed | Avoid large decorative comment blocks and duplicated explanations. | No authored decorative comment banners were introduced; the original reference file remains unchanged. |
| 80 | completed | Do not generate roxygen2 or misreport documentation status. | No documentation generator ran and no Rd output changed in this transition. |
| 81 | blocked | Run focused tests for conversion, runtime, persistence, and workflows. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 82 | blocked | Run R CMD build and R CMD check on the changed package. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 83 | blocked | Run CI or equivalent checks on supported OS and architectures. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 84 | not applicable | Test without optional OpenMP if that remains relevant. | Intel OpenMP is required by the supplied reference profile. |
| 85 | blocked | Run the package on a host without the prohibited interpreter installed. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 86 | blocked | Inspect installed native dependencies for forbidden runtime linkage. | Source implementation/prior Windows evidence exists; acceptance in the Intel Fedora reference is blocked before package execution. |
| 87 | blocked | Record exact ORT release, asset, digest, compiler, and test commands. | Compiler/R-source/profile provenance retained; installed ORT asset/hash and package-test results are unavailable. |
| 88 | completed | Report any unsupported platform, incomplete test, warning, or deviation. | VALIDATION.md and validation_attempts.csv record twelve Intel failures, warnings, unexecuted phases and diagnostic limits. |
| 89 | completed | Do not state that the package works on every ONNX model or every R model. | Source conversion and numeric graph support stay explicitly bounded; no universal support claim is made. |
