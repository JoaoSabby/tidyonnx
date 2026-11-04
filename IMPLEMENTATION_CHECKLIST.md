> Historical acceptance record: the current reference requires the latest stable
> Fedora/R Docker environment, Intel oneAPI and the supplied Makevars.001 profile.
> The completed items below describe the previous Windows implementation.
> Intel reference execution is pending; these items do not claim Intel success.
> See tools/docker/README.md and the current section of VALIDATION.md.

# Current reference transition checklist

| Item | Status | Evidence or limitation |
| --- | --- | --- |
| Preserve the supplied profile and verify its SHA-256. | completed | Unchanged reference copied; mandatory image hash check. |
| Configure latest Fedora/R and Intel for R, source dependencies and package builds. | completed | Dockerfile, profile adapter and bootstrap configuration; execution pending. |
| Retain profile optimization settings and avoid silent fallbacks. | completed | Full original profile included; missing compiler, ISA or release metadata fails. |
| Run on a CPU supporting the profile and verify AVX-512 execution. | blocked | Requires the Intel reference run and its execution artifacts. |
| Complete installation, all tests, independent predictions and package checks in Intel Docker. | blocked | Pending Intel reference run; earlier Windows/GCC results are historical. |
| Rebuild the upstream ONNX Runtime binary with Intel. | not applicable | Contract pins the official precompiled Microsoft release. |
| Merge main or publish a package release. | not applicable | Testing is confined to a separate branch. |

# Implementation checklist

Validated on PC-TOHP2, 2026-11-03. Each original checklist item appears once.
Statuses describe this local implementation and its executed evidence, not remote support.

| # | Status | Requirement | Evidence or limitation |
| --- | --- | --- | --- |
| 1 | completed | Confirm PC-TOHP2, the exact local folder, repository name, branch, commit, remote, and working-tree status before edits. | PC-TOHP2; canonical checkout; main; baseline d8a77cb; origin URL and initial status recorded. |
| 2 | completed | Preserve pre-existing local changes; do not reset or replace the checkout. | Three pre-existing untracked files retain their hashes; the original Rbuildignore additions remain local. |
| 3 | completed | Read DESCRIPTION, NAMESPACE, R, src, tests, CI, and current evidence. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 4 | completed | Record which existing behaviors are preserved and which intentionally change. | README and ARCHITECTURE record runtime, metadata, settings, class ties and persistence changes. |
| 5 | completed | Evolve the existing package instead of replacing it wholesale. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 6 | completed | Keep all changes in the tidyonnx repository; do not touch sbyonnx. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 7 | completed | Do not claim any test passed before executing it on the changed code. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 8 | completed | Pin ONNX Runtime exactly to v1.31.1. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 9 | completed | Store all supported platform asset names, URLs, and SHA-256 values. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 10 | completed | Confirm each manifest URL points to the official Microsoft release. | All six manifest URLs and digests match the fixed official release metadata. |
| 11 | completed | Select assets by OS and CPU architecture, not OS name alone. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 12 | completed | Reject unsupported architectures and missing assets explicitly. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 13 | completed | Do not use releases/latest or a silent fallback to another version. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 14 | completed | Download the selected archive during install without another language runtime. | Normal staged source installation downloaded the Windows x64 asset successfully. |
| 15 | completed | Fail clearly on network, TLS, HTTP, or permission errors. | Specific download/status/digest/layout/permission errors are implemented; actual positive transfer passed. |
| 16 | completed | Verify SHA-256 before unpacking. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 17 | completed | Reject archive path traversal and unexpected layout. | Traversal, drive, backslash and unexpected-root fixtures fail before extraction. |
| 18 | completed | Install required license and notice files. | Installed LICENSE, notices and version files verified. |
| 19 | completed | Install native library privately and load only that version. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 20 | completed | Check header/library API compatibility. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 21 | completed | Record installed runtime version and hash for diagnostics. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 22 | completed | Verify no package-authored source file contains the prohibited word. | Authored-source scan passed; unchanged handoff references and upstream files are separate evidence. |
| 23 | completed | Verify no package install/build/test command invokes its interpreter. | R/configure/compiler/standalone C API commands only; no interpreter invocation. |
| 24 | blocked | Inspect binary dependencies for an interpreter runtime on each platform. | Only the Windows x64 package, runtime and provider DLL imports were inspected on this host. |
| 25 | completed | Test a client installation with that interpreter absent from PATH. | Normal source install and full tests ran with R/compiler/system-only PATH. |
| 26 | blocked | Test the exact remotes::install_github command on Oracle Linux 9.8 x64. | An Oracle Linux 9.8 x64 client and a remote revision containing these local changes are unavailable. |
| 27 | blocked | Test Windows x64 and macOS arm64 installation and loading. | Windows x64 install/load passed; no macOS arm64 host is available in this session. |
| 28 | completed | Make macOS x86_64 fail clearly under the fixed-release policy. | Asset-selection tests explicitly reject Darwin x86_64. |
| 29 | completed | Preserve current six XGBoost objective paths or document a justified removal. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 30 | completed | Keep one shared tree parser/serializer for supported objectives. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 31 | completed | Preserve binary and two-class score semantics in independent runtimes. | Twelve standalone C API scenarios, including two-class softmax, pass at 5e-6 tolerance. |
| 32 | completed | Keep XGBoost native JSON export with raw_format = "json". | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 33 | completed | Validate default feature names and explicit feature_names. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 34 | completed | Reject duplicate, missing, or wrong-length names. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 35 | completed | Define and test target_name as metadata rather than guessed class labels. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 36 | completed | Preserve a deliberate route for direct custom class labels. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 37 | completed | Verify ONNX session creation for every supported converted objective. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 38 | completed | Compare predictions with XGBoost and the current implementation. | Six objectives compared with XGBoost; two saved baseline models compare with the former evaluator. |
| 39 | completed | Verify external ONNX Runtime independently consumes saved files. | A separately compiled executable consumes saved ONNX bytes through C API 31. |
| 40 | completed | Update onnx_model invariants for generic session metadata. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 41 | completed | Keep portable bytes or a documented backing-file contract. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 42 | completed | Protect and release native resources on all success and error paths. | Scope guards cover options, type info, metadata, tensors and partial Run outputs; session owns library. |
| 43 | completed | Restore sessions after readRDS without trusting serialized pointers. | Current RDS restoration and actual 0.1.0 embedded-artifact migration executed. |
| 44 | completed | Detect changed backing files when restoring a file-backed model. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 45 | completed | Verify repeated load, save, copy, garbage collection, and unload paths. | Repeated persistence/GC tests and a fresh-process namespace reload passed. |
| 46 | completed | Preserve exact ONNX file bytes across save/load where intended. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 47 | completed | Prevent partial replacement of an existing destination on write failure. | Injected replacement failure restored original destination bytes through the backup path. |
| 48 | completed | Implement the supported named tensor input contract and reject others. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 49 | completed | Check input names, element types, shapes, dimensions, and row counts. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 50 | completed | Handle zero-row batches explicitly where runtime semantics permit. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 51 | completed | Check allocation limits and integer overflow before native allocation. | Per-tensor rank/count/byte/precision bounds checked before IO allocation; internal runtime workspace is separate. |
| 52 | completed | Return named outputs with dimensions and documented R storage types. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 53 | completed | Release every OrtValue and status object, including on failure. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 54 | completed | Keep onnx_run free of tidy class/probability interpretation. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 55 | completed | Keep onnx_predict outputs stable for supported tabular models. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 56 | completed | Preserve type = "raw" compatibility or document an approved migration. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 57 | completed | Verify probabilities, labels, class order, and missing-value routing. | Parity and class-order tests pass; the exact 0.5 graph-label/tidy-label difference is recorded explicitly. |
| 58 | completed | Reject unsupported external model output shapes without guessing. | Non-tensor, unsupported element types and unresolved output shapes fail explicitly. |
| 59 | completed | add_onnx marks an artifact request without changing preprocessing. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 60 | completed | Direct fit invokes the ordinary workflow fit exactly once. | The narrow S3 adapter calls the public fit generic once on the ordinary workflow. |
| 61 | completed | Conversion receives the fitted engine, not the untrained specification. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 62 | completed | Extract names and levels through public workflow accessors. | Public extract_fit_engine, extract_mold and extract_fit_parsnip accessors supply the fitted contract. |
| 63 | completed | Validate extracted names and levels against engine and ONNX metadata. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 64 | completed | Attach a complete S7 ONNX artifact to the fitted workflow. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 65 | completed | extract_fit_onnx returns the artifact or a clear absence error. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 66 | completed | Ordinary predict on the fitted workflow remains unchanged. | Ordinary and requested workflow predictions compared on identical fitted inputs. |
| 67 | completed | Fail fit clearly if requested conversion fails. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 68 | completed | Add no tuning or resampling integration and make no such claim. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 69 | completed | Test formulas and simple recipes that produce supported numeric engines. | Formula binary/multiclass workflows and a numeric normalization recipe executed. |
| 70 | completed | Reject unsupported recipe-to-engine data contracts clearly. | Plain-numeric prepared predictors and exact engine-name/order guards reject unsupported contracts. |
| 71 | completed | Enable R byte compilation and verify it in the installed package. | Installed function disassembly and fresh-process validation verify R bytecode. |
| 72 | completed | Apply -O3 to package-owned native code where supported. | Final compile commands show -O3 after configured R flags for package-owned objects. |
| 73 | completed | Avoid unsafe floating-point flags and unmeasured optimization claims. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 74 | completed | Benchmark small and large batches against the previous native evaluator. | 15/300-round models; 1/100000-row batches; baseline and current latency CSVs retained. |
| 75 | completed | Measure conversion time and memory for small and large XGBoost models. | Conversion elapsed time and Rprofmem allocated bytes measured for 15/300-round models; native peak not measured. |
| 76 | completed | Keep public and internal naming consistent with STYLE_GUIDE.md. | Public/internal entry points and authored filenames follow the agreed naming rules; required protocols are exceptions. |
| 77 | completed | Give every authored function concise formal English ASCII comments. | Authored function and helper comments reviewed; standard generated cpp11 registration remains generated. |
| 78 | completed | Enforce comment width of at most 90 characters. | Automated authored-comment ASCII and <=90 character scan passed. |
| 79 | completed | Avoid large decorative comment blocks and duplicated explanations. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 80 | completed | Do not generate roxygen2 or misreport documentation status. | No Rd file was modified or documentation generator invoked; two documentation warnings are reported. |
| 81 | completed | Run focused tests for conversion, runtime, persistence, and workflows. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
| 82 | completed | Run R CMD build and R CMD check on the changed package. | Source build and source-archive package check executed; final log records the exact warning status. |
| 83 | blocked | Run CI or equivalent checks on supported OS and architectures. | No remote CI was dispatched for these local-only changes; Linux/ARM/macOS checks remain unexecuted. |
| 84 | not applicable | Test without optional OpenMP if that remains relevant. | The former package OpenMP evaluator and compilation target were removed; ONNX Runtime owns threading. |
| 85 | blocked | Run the package on a host without the prohibited interpreter installed. | The restricted PATH excludes the interpreter; physical absence from the Windows installation was not established. |
| 86 | completed | Inspect installed native dependencies for forbidden runtime linkage. | objdump import tables for package/runtime/provider DLLs contain no excluded interpreter dependency. |
| 87 | completed | Record exact ORT release, asset, digest, compiler, and test commands. | VALIDATION records release, hashes, compiler, commands and exact local evidence paths. |
| 88 | completed | Report any unsupported platform, incomplete test, warning, or deviation. | External platform gates, legacy file-backed migration, total workspace and documentation limits are explicit. |
| 89 | completed | Do not state that the package works on every ONNX model or every R model. | Implemented and reviewed in the local source; relevant focused tests and package checks are recorded in VALIDATION.md. |
