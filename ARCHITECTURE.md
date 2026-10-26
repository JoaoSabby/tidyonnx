# Architecture

## Entry points and prediction contracts

`onnx_convert()` is an S3 generic with methods for XGBoost engines, parsnip fits,
and workflows. Existing native S7 models and converted bundles can be passed
through unchanged. Additional arguments and unsupported engine classes fail
explicitly.

| Input | Converted representation | Prediction preparation |
| --- | --- | --- |
| `xgb.Booster` | Native S7 `onnx_model` | Numerical input alignment |
| `model_fit` | `onnx_fit` bundle | Saved parsnip preprocessing |
| `workflow` | `onnx_fit` bundle | Trained hardhat blueprint, then parsnip encoding |

A bundle retains a minimal parsnip prediction specification, its preprocessing,
and optionally a trained workflow blueprint. The fitted engine, model tuning
arguments, and training call are not retained as bundle components. Formula
expressions can retain environments needed for prediction; recipe steps can
retain their own fitted state. No universal memory-reduction ratio is promised.

Binary target mapping is derived from the fitted parsnip probability
postprocessor using sentinel scores. This preserves the fitted prediction
contract without depending on the internal representation of engine argument
expressions. Outcome levels remain in their original order in formatted output.
Workflow postprocessors are rejected because the converter does not export their
semantics. A bundle has its own prediction class and does not pretend to support
all extraction, tuning, or refitting methods of an unconverted workflow.

## Conversion and native ownership

XGBoost's stable model JSON is parsed once for ordinary conversion. A saved
best iteration is honored by slicing through the public XGBoost API and reading
the sliced model when necessary. An explicit `iteration_range = "all"` retains
all stored trees. No source engine is modified.

The C++ serializer reads numerical trees, tree-to-class assignments, supported
objectives, scalar or vector intercepts, and feature counts. Vendored Nanopb
0.4.9.1 encodes a standard binary ModelProto. ONNX ML opset three is used; the
standard opset and IR versions are bounded conversion settings. Names and labels
use UTF-8 newline-delimited metadata and therefore reject line breaks.

The model constructor decodes and validates the resulting graph once before
publishing a session. Native vectors own all graph storage through RAII.
`cpp11::external_pointer` finalizes the session. The R object retains portable
bytes by default and a shared cache for lazy restoration after serialization.
File-backed objects verify their saved checksum before restoration. The checksum
is an accidental-change check, not an authenticity mechanism.

## Graph validation

The bounded wire parser validates message wire types and integer bounds before
nested decoding. Packed and unpacked repeated attributes are supported. Signed
integer class labels preserve their signed values; structural identifiers remain
nonnegative. Attribute type declarations must agree with each specific operator
attribute. Classifier and regressor attributes cannot be mixed.

Before inference, the graph validator checks topology, child references,
identifier uniqueness, array lengths, roots, reachability, feature bounds,
finite thresholds and weights, graph IO schemas, output labels, and supported
aggregation and activation semantics. Traversal is iterative for deep trees.
Unsupported preprocessing operators, tensor attributes, initializers, and
single-score binary encodings fail before a session can be used.

## Portable classifier semantics

Converted binary logistic leaves encode two symmetric class scores, followed by
LOGISTIC. A constant intercept tree avoids ambiguous binary `base_values`
handling in reference implementations. Multiclass graphs also use a constant
intercept tree. Two-class softmax uses symmetric half-difference scores.
Logistic regression adds an explicit standard-domain Sigmoid after an
untransformed single-target regressor.

The additional intercept tree is visible in inspection. External classifiers
select the largest class score. Converted binary logistic models preserve the
positive-class decision at a probability of 0.5.

## Inference and persistence

Plain integer and double R column buffers are borrowed by the native bridge.
ALTREP materializes on the main R thread before worker access. C traversal casts
individual values to float32, follows stored missing directions, and accumulates
trees in a fixed order. Predictions use column-major output buffers.

No R API, exceptions, dynamic allocation, or global OpenMP changes occur in the
worker region. Physical-core detection is cached. The requested worker limit is
bounded to 1024 and further limited by batch size. Builds without OpenMP remain
serial. Output and per-worker score buffers still allocate.

Graph writes are staged in the destination directory. Atomic replacement is
used where available. A platform fallback moves the original to a backup before
publishing and restores it on failure. R preprocessing cannot be written into a
tree-only ONNX graph; bundles therefore use RDS and are rejected by `onnx_save()`.

## Sources

- [ONNX intermediate representation](https://onnx.ai/onnx/repo-docs/IR.html)
- [ONNX 1.17 schema](https://github.com/onnx/onnx/blob/v1.17.0/onnx/onnx-ml.proto3)
- [ONNX-ML operators](https://onnx.ai/onnx/operators/)
- [XGBoost model IO](https://xgboost.readthedocs.io/en/stable/tutorials/saving_model.html)
- [Hardhat forge](https://hardhat.tidymodels.org/reference/forge.html)
- [Parsnip prediction](https://parsnip.tidymodels.org/reference/predict.model_fit.html)
- [Workflow prediction](https://workflows.tidymodels.org/reference/predict-workflow.html)
- [cpp11 ownership](https://cpp11.r-lib.org/)
- [Nanopb 0.4.9.1](https://github.com/nanopb/nanopb/tree/0.4.9.1)
