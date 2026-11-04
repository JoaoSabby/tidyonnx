# tidyonnx

Convert supported numerical XGBoost models to portable ONNX files and execute
numeric tensors through ONNX Runtime **1.31.1**, using its C API and cpp11.
The model artifact is S7; recognized tabular predictions are tibbles.

```r
library(tidyonnx)
model <- onnx_convert(fitted_engine, target_name = "outcome")
onnx_save(model, "model.onnx")
onnx_predict(onnx_load("model.onnx"), new_data)
```

## Installation

R 4.3 or newer and a compatible development toolchain are required.

```r
remotes::install_github("JoaoSabby/tidyonnx")
```

The source installer downloads the official Microsoft CPU archive for exactly
v1.31.1, verifies its SHA-256 before extraction, validates archive paths, and
installs the C runtime, license and notices privately in the package. Network
access to that release is required. There is no source-build, mirror, offline
or system-library fallback. XGBoost is optional for loading and inference.

Supported asset selections are Windows x64/arm64/arm64x, Linux x64/aarch64,
and macOS arm64. The selected architecture is the running R architecture.
There is no macOS x86_64 asset in this fixed release; that platform fails
explicitly. Oracle Linux 9.8 x86_64 selects Linux x64; actual client validation
is still required. See VALIDATION.md for the platforms tested on this revision.

The full manifest is in `inst/install/runtime_manifest.csv`. Inspect the
installed runtime version, asset and archive/library hashes with
`onnx_inspect(model)$engine`. Loading verifies the private library hash, and
initialization requires the exact runtime release and matching C API version.
No unrelated interpreter is required by the authored installer or runtime.
Windows also requires the Microsoft Visual C++ runtime libraries imported by
the official binary; these were present on the validated host.
Official third-party notices and binaries retain their upstream contents.

## Conversion coverage

| XGBoost objective | ONNX graph | Tidy output |
| --- | --- | --- |
| binary:logistic | TreeEnsembleClassifier | Two probabilities or factor class |
| binary:logitraw | TreeEnsembleRegressor | Raw margin |
| reg:squarederror | TreeEnsembleRegressor | Numeric response |
| reg:logistic | TreeEnsembleRegressor + Sigmoid | Logistic response |
| multi:softprob | TreeEnsembleClassifier | Probabilities or factor class |
| multi:softmax | TreeEnsembleClassifier | Probabilities or factor class |

One shared serializer handles these objectives, scalar/vector intercepts, and
parallel trees. Native XGBoost export generates JSON with `raw_format = "json"`;
jsonlite parses it for the existing C++ serializer. All stored trees are exported.
Categorical splits, DART, linear boosters, vector leaves, multiple regression
targets and other model engines are rejected. Conversion from arbitrary R
models is not implemented.

`onnx_convert(model, feature_names = NULL, params = list(), target_name = NULL)`
retains the original positional arguments. Feature names come from the engine,
or use `f0`, `f1`, ... when no names exist. Explicit names must be unique,
nonempty, complete and free of line breaks. `target_name` is outcome metadata;
it does not change class IDs or output tensor names. Direct boosters normally
lack factor labels: supply `params = list(class_levels = c("absent", "present"))`
when those labels are known. The default labels are numeric class IDs as strings.

## Named tensors

```r
outputs <- onnx_run(model, list(features = as.matrix(prepared_predictors)))
```

`onnx_run()` accepts a uniquely named list matching the session inputs. Inputs
may be plain integer or numeric vectors/arrays. It validates tensor names,
ranks, fixed dimensions and shared symbolic dimensions. R column-major storage
is reordered explicitly for ONNX; output names, axis order and dimensions are
preserved. Scalars are length-one vectors without a dimension attribute.
Rank-one outputs retain a one-dimensional array attribute.

Supported ONNX element types are float32, float64, int32 and int64. Float outputs
use R double storage; float32 precision remains the graph's precision. Int32
outputs use R integers. Int64 outputs use exact R doubles only within +/-2^53;
values outside that range fail. The reserved R int32 missing sentinel also
fails. Floating inputs allow NA/NaN; integer tensors reject missing and fractional
values. Infinities and float32 overflow fail explicitly.

Each tensor is limited to 32 dimensions and a conservative 2 GB allocation
bound. Output shapes must be fixed or resolvable from named input dimensions
before execution. Data-dependent output shapes, maps, sequences, sparse values,
strings, custom values and other element types are rejected. These checks do
not impose a total memory quota on ONNX Runtime's internal graph workspace.
Only CPU execution is exposed. Session opening does not establish a supported
R input/output mapping for every ONNX graph.

## Tidy predictions

```r
onnx_predict(model, new_data)                   # Probabilities or regression .pred
onnx_predict(model, new_data, type = "class")   # Factor .pred_class
onnx_predict(model, new_data, type = "numeric") # Regression or binary positive score
onnx_predict(model, new_data, type = "raw")     # Vector or probability matrix
predict(model, new_data)                       # stats::predict compatibility
onnx_inspect(model)                            # Runtime tensors and recognized metadata
```

Tidy prediction requires package-recognized task metadata and matching tensors.
External models without that contract remain usable through `onnx_run()` when
their tensor mapping is supported. Tree counts are unknown for external graphs,
unless supplied as recognized provenance metadata; they are never fabricated.

Named columns are aligned to saved feature order. Extra data-frame columns
are ignored; unnamed matrices use column order. Factors, dates, strings,
duplicate names and incorrect widths fail. Missing floats follow graph semantics.
Empty supported batches preserve zero rows. Probability columns and factor
levels preserve the model's saved class order. `type = "raw"` keeps its original
unformatted meaning; it does not request file bytes or pre-activation margins.
At an exact binary probability of 0.5, the tidy layer preserves its positive-class
tie rule. The v1.31.1 graph label chooses class ID 0 in the tested symmetric
encoding. `onnx_run()` exposes that label unchanged; the two decisions are tested
separately and agree away from ties for the converted binary contract.

## Direct workflow artifacts

```r
requested <- add_onnx(workflow)
fitted <- generics::fit(requested, data = training_data)
artifact <- extract_fit_onnx(fitted)
predict(fitted, new_data)                     # Ordinary workflow preprocessing
onnx_predict(artifact, prepared_predictors)   # Prepared engine inputs only
```

A narrow S3 workflow subclass calls ordinary fit once, then uses public workflow
accessors to obtain the engine, prepared predictors, outcome name and levels.
The adapter checks engine feature order, encodes binary class orientation, and
compares a prediction probe before attaching the complete S7 artifact. Conversion
failure fails the requested fit. A formula and simple numeric recipes are
supported; unsupported recipe-to-engine contracts fail explicitly. The recipe
is retained in the workflow and is never translated into ONNX operators.
Tuning, resampling and last-fit hooks are outside this version.

## Persistence and settings

Embedded model bytes survive RDS and restore disposable native sessions. With
`onnx_load(file, params = list(embed_raw_bytes = FALSE))`, the backing file must
remain available and byte-identical. A SHA-256 check rejects replacement even
when the new file has the same schema. File saving preserves exact bytes and
uses same-directory staging, a backup and rollback on replacement failure.
On Windows this recovery strategy has a brief interval without the final name;
it is not a cross-process atomic transaction.

Embedded 0.1.0 RDS artifacts migrate through their portable bytes and checked
feature/task/class metadata. Legacy file-backed RDS artifacts lack a source
digest and require an explicit `onnx_load()` call instead of unverifiable migration.

| Parameter | Default | Effective scope |
| --- | --- | --- |
| target_opset | 18L | Conversion only; standard domain 18-21 |
| ir_version | 8L | Conversion only; model IR 8-10 |
| float_precision | "float32" | Conversion only; other serialization types rejected |
| embed_raw_bytes | TRUE | Loading only; conversion always embeds bytes |
| class_levels | NULL | Conversion only; direct labels must be explicitly known |
| execution_provider | "cpu" | CPU sessions only |
| intra_op_threads | 1L | Session worker setting; 0 delegates selection to the runtime |
| inter_op_threads | 1L | Session setting; other values rejected in this version |
| graph_opt_level | "all" | Runtime graph optimization; "all" or "disable" |
| log_severity | "error" | Runtime session logging threshold |

Unlike the former evaluator, runtime optimization and logging now reach the
C API. Conversion settings are rejected when supplied to load, predict or
inspect instead of being silently ignored. Prediction or inspection with runtime
settings recreates a session when needed; subsequent calls reuse its cache.
Existing ONNX bytes cannot be relabeled or reserialized through conversion.

R source is byte-compiled. Package-owned native code appends `-O3` with the
R toolchain; `TIDYONNX_OPT_FLAGS` may override that option. No unsafe floating
point or host-specific CPU flags are injected. Package OpenMP execution has
been removed; runtime threading is owned by ONNX Runtime.

## Development

No documentation generation is performed in this phase. Existing Rd files are
unchanged, so checks may report missing entries or signature mismatches for the
new API. See VALIDATION.md for exact checks, benchmarks and outstanding gates.
The independent C API executable in `tools/validate_runtime.cpp` validates
saved ONNX files without loading R. Authored source and comment policy checks
exclude unchanged handoff references and downloaded third-party files.

## Canonical test environment

All validation now runs inside Docker with the latest stable Fedora Linux
and the latest stable CRAN R release. From this checkout, run
`pwsh -NoProfile -File tools/run_fedora_tests.ps1` on Windows, or
`sh tools/run_fedora_tests.sh` on Linux. Every package test and check executes
inside the image; the host only launches Docker. Existing R validation entry
points delegate to the same full container suite.

See [the Fedora test guide](tools/docker/README.md) for version discovery,
provenance, phases and prerequisites. GitHub Actions builds and runs the Fedora
container; Docker on PC-TOHP2 is optional. The previous 280-expectation
Windows result is historical and is not a Fedora result.

## Intel reference validation

The reference uses latest stable Fedora/R in Docker, Intel oneAPI and the supplied
Makevars.001 profile. The original profile is preserved with a verified SHA-256.
Compatible CPUs passed AVX-512 probes, but shared ABI validation and R compilation failed;
no successful Intel package test result is claimed. See tools/docker/README.md
and VALIDATION.md for exact run results and compatible-runner configuration.
