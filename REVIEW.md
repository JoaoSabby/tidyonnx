# tidyonnx review

Reviewed on 2026-10-26. Baseline: `d8a77cbf6bfe681fa43760e69e1e882053bed546`.
Resulting package version: **0.1.1**.

## Scope and traversal

The review started at `onnx_convert()`, `onnx_save()`, `onnx_load()`,
`onnx_predict()`, `predict()`, and `onnx_inspect()`. Each entry point was followed
through parameter validation, model extraction, JSON serialization, ONNX wire
encoding and decoding, schema and topology checks, native ownership, C traversal,
output formatting, persistence, and session restoration. The second pass checked
every named R function and its generated reference documentation.

## Findings and applied changes

| Finding | Consequence | Applied correction |
| --- | --- | --- |
| Early-stopped models exported all stored iterations | Conversion could disagree with default source predictions; a deterministic binary fixture differed by approximately 0.00593 | The saved best iteration is honored through the public XGBoost slicing API; all iterations remain available explicitly |
| No parsnip or workflow conversion methods | Final fitted tidymodels pipelines could not be converted directly | Added S3 conversion methods and prediction bundles retaining required preprocessing |
| Binary event ordering was not represented | Binary outcome probabilities could be associated with the wrong factor level | Derived the fitted probability mapping and retained original output level order |
| Full model specifications could retain unevaluated fitting arguments | Converted bundles could retain unnecessary fitting state and captured environments | Retained only the prediction specification, preprocessing, native model, and optional workflow blueprint |
| Graph validation ran during encoding and again during construction | Duplicate graph decoding and allocation | Validation now runs once when the owned session is created |
| Exact vector capacity was reserved for every source tree | Repeated copying of accumulated node arrays | Restored amortized geometric vector growth |
| Existing files were overwritten by copying into the destination | A failed publication could truncate an existing model file | Added staged rename publication with a backup-and-rollback fallback |
| File-backed restoration checked schema but not model identity | A replacement with the same schema could silently change predictions | Saved and verified file checksums before restoration and graph-only saving |
| Core detection ran on each automatic-thread inference call | Avoidable repeated system queries and oversized small-batch teams | Cached core detection, bounded worker limits, and limited teams by batch size |
| External binary class decisions always used a probability threshold | Non-complementary external scores could select the wrong class | Used the largest score for external classifiers while retaining converted binary logistic threshold behavior |
| Signed integer class labels were treated as structural identifiers | Valid negative class labels were rejected | Decoded signed label values while retaining nonnegative structural IDs |
| Version integers could narrow before range validation | Oversized identifiers could wrap into an accepted version | Added checked integer narrowing |
| Nested message wire types and operator-specific attribute types were incomplete | Invalid graph encodings could pass preliminary decoding | Added explicit message, attribute-type, and operator-family checks |
| Finite double predictors could overflow on float32 conversion | Values outside the source engine's supported range were accepted | Rejected out-of-range finite predictors before traversal |
| Data-frame column extraction dispatched through subclass row semantics | `data.table` input could fail despite satisfying the documented input contract | Extracted columns through a plain list representation |
| Most named R functions lacked roxygen2 source headers | Documentation could drift from implementation | Added English source documentation and regenerated reference pages and namespace |
| Vendored descriptor headers named a generator script | Source documentation retained an unnecessary interpreter-specific reference | Generalized the two comments, retained licenses, and marked local documentation edits |

## Integration contract

Conversion occurs after model selection and final fitting, in the same pipeline
position as butcher. A fitted engine becomes a native S7 model. A parsnip fit or
workflow becomes an `onnx_fit` prediction bundle. Existing fitted engine objects
are not modified.

Bundles retain original-data preprocessing, outcome ordering, standardized
prediction columns, and RDS restoration. Their fitted XGBoost engine is removed.
Formula environments and trained recipe state needed by prediction may remain.
The converted class supports prediction and inspection; it does not claim all
refitting, tuning, or extraction methods of an unconverted workflow.

A tree-only ONNX graph cannot contain retained R preprocessing. `onnx_save()`
therefore rejects bundles. Complete bundles use `saveRDS()`; extracted engines
can be exported when the consumer supplies already processed predictors.
Unsupported workflow postprocessors and incompatible objective/mode pairs fail
explicitly. Preprocessing must produce dense numerical predictors for this
inference engine.

## Documentation and metadata

All **33 named package R functions**, including native wrappers and lifecycle
helpers, have roxygen2 headers. Test helper functions are also documented in
source. Applicable tags describe behavior, parameters, returns, examples,
sections, references, families, internal visibility, and method registration.
Usage is generated from current signatures to avoid duplicated stale usage text.
The canonical native wrapper headers are retained by `tools/document.R` after
cpp11 regeneration.

The README includes executed `modeldata` penguin examples for direct XGBoost,
parsnip fits, recipe workflows, butcher pipelines, and persistence. Lifecycle,
R-version, license, and GitHub Actions badges are included without claiming a
CRAN release or external coverage service. Package authorship and `inst/CITATION`
use **João B. G. de Brito**, the established contact address, version, year, and
repository URL.

The source audit found no prohibited dependency references or prohibited source
file formats in the resulting repository snapshot. CI runs the same source and
documentation-coverage check before package validation. Historical Git objects
are outside the snapshot audit.

## Executed verification

* `R CMD build`: passed; the source archive contains no compiled object files,
  shared libraries, or native symbol-cache files.
* `R CMD check --no-manual`: **Status: OK**, zero errors, warnings, and notes.
* **34 tests and 192 passing expectations**, with zero failures, skips, or
  warnings, in both OpenMP-enabled and OpenMP-disabled installations.
* All README modeling examples executed, including the equality assertion between
  original and converted workflow probabilities.
* Fresh-process prediction succeeded for native and workflow bundles without
  loading the source engine namespace.
* Twelve independent ONNX Runtime C API scenarios passed at a 5e-6 absolute
  tolerance; see [VALIDATION.md](VALIDATION.md) for measurements.
* `git diff --check`: passed.

## Conversion benchmark

Both revisions converted the same 800-tree regression model with 2,000 rows,
eight numerical features, one warm-up, and seven measured repetitions in separate
R processes on the same Linux environment.

| Version | Median conversion time | Minimum conversion time |
| --- | ---: | ---: |
| 0.1.0 baseline | 0.188 s | 0.183 s |
| 0.1.1 review | 0.134 s | 0.127 s |

The observed median reduction was **28.7%**, approximately **1.40 times** the
baseline conversion throughput. Both versions had the same maximum prediction
difference from XGBoost, 8.583069e-6, on this longer regression ensemble. The
benchmark used a scale-adjusted float32 acceptance bound of 5.330251e-5. These
measurements describe this fixture and environment; they do not establish a
production inference speedup or a hardware-independent conversion factor.

Reproduction code and machine-readable results are in `tools/benchmark.R`,
`tools/evidence/review-benchmark.csv`, `tools/evidence/review-test-results.csv`,
`tools/evidence/review-test-results-no-openmp.csv`, and
`tools/evidence/review-runtime-equivalence.csv`.
