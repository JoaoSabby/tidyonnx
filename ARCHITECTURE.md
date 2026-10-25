# Architecture decisions

## Conflicting attachment requirements

The supplied specification simultaneously requires an ONNX Runtime/libprotobuf
implementation and a Route A implementation with no external inference or
protobuf libraries. These cannot be the same default execution engine.
Version 0.1.0 follows the explicit Route A mandate. The R interface remains S7,
the native bridge remains exclusively cpp11, and the evaluator remains pure C.
There is no OrtEnv singleton because this engine has no OrtEnv resource.
A session is an immutable validated tree representation owned by
`cpp11::external_pointer<Session>`.

Nanopb 0.4.9.1 is vendored with its license. It is a compiled C library, not a
header-only library. Its bounded wire primitives encode/decode the required
ONNX fields. `src/proto_generated/onnx.pb.h` is audited, manually maintained
field-number metadata, not an automatically generated full ONNX descriptor.
The complete upstream ONNX 1.17.0 schema is included for provenance. No
misleading generated descriptor or unused schema compilation step is included.

## Data flow

1. R exports a fitted XGBoost model using its stable JSON model API.
2. jsonlite reads the model; C++'s XGBoost serializer extracts numerical trees,
   tree assignments, objective, and intercept.
3. Nanopb emits a standard binary ModelProto with ML opset 3 and standard opset
   18 by default. Names and labels are stored as UTF-8 newline-delimited metadata;
   names containing line breaks are rejected.
4. The same bounded parser validates loaded bytes. C++ validates topology,
   array lengths, identifier uniqueness, roots, reachability, finite weights,
   feature bounds, and supported graph semantics before publishing a session.
5. C receives immutable node/weight arrays and borrowed R column pointers.
   It reads integer and double features directly, casts individual values to
   float32 as XGBoost does, traverses trees, and writes column-major R output.
   No full input matrix conversion or row-major copy is required.
6. cpp11 finalizes the session. Embedded ONNX bytes and a shared cache environment
   rehydrate external pointers after R serialization.

## Binary classifier portability

The attachment's single class-0 weight encoding has an ONNX Runtime special
case: positive-only binary weights can bypass the expected logistic conversion.
Its handling of two class scores plus nonzero base_values is also ambiguous.
The exported classifier therefore has two explicit class scores. Binary leaves
write `[-weight, +weight]` and the constant intercept tree writes
`[-logit(base_score), +logit(base_score)]`. LOGISTIC then produces complementary
probabilities in independent runtimes. The same intercept-stump approach is used
for multiclass scores. Regression uses standard base_values. Scalar logistic regression uses an explicit
standard-domain Sigmoid after an untransformed regressor: ONNX Runtime 1.20.1
does not apply TreeEnsembleRegressor LOGISTIC in its single-target fast path.
This is a second correction to the attachment demonstrated by independent execution.
Two-class softmax models use symmetric half-difference scores to preserve both
probabilities and the binary label decision in reference runtimes.

The constant intercept tree is visible in inspection: a converted classifier
has one more ONNX tree than the source model. This intentional encoding
preserves predictions without runtime-specific metadata interpretation.

## Performance and numerical contract

Nodes and weights occupy contiguous vectors. Input handoff borrows existing R
column buffers; R ALTREP data may materialize before worker threads start.
Metadata, pointer tables, output, and per-thread score workspace still allocate.
There are no R API calls, allocations, or C++ exceptions inside the worker region.
OpenMP distributes independent rows with an explicit per-call worker limit.
Tree accumulation order remains fixed. Traversal is branch-dependent and is
not claimed to achieve vectorized tree walking.

Float32 arithmetic is preserved. Small differences in transcendental functions
or base-score accumulation order mean bitwise equality with every external
runtime is not promised. Validation uses explicit numerical tolerances.
No fast-math or host-only instruction flags are injected because they can break
NaN routing or portability. R's configured compiler, optimization, and OpenMP
flags determine the build. Intel compiler users may select an appropriate
toolchain through R's standard user Makevars configuration; Intel/AVX-512
performance is not claimed without a measured production run.

## Extensibility and deliberately bounded support

Serializer modules implement an abstract C++ Serializer interface and register
in the bridge registry. Adding an adapter does not require editing the C
inference core. Only XGBoost is registered in v1; lm, glm, randomForest, and
LightGBM are future adapters, not aliases with partial conversions.

The loader supports a documented subset of ONNX-ML, plus a standard Sigmoid
directly after a regression ensemble. It rejects unsupported
operators, attribute encodings, graph pipelines, aggregation modes, and
single-score binary encodings. It does not claim general ONNX compatibility.
The engine is CPU-only. Inter-op concurrency is one; tuning values for GPU,
float64 serialization, and unsupported graph optimization levels fail explicitly.

## Sources

- [ONNX 1.17 schema](https://github.com/onnx/onnx/blob/v1.17.0/onnx/onnx-ml.proto3)
- [ONNX-ML operator definitions](https://github.com/onnx/onnx/blob/v1.17.0/onnx/defs/traditionalml/defs.cc)
- [ONNX Runtime classifier aggregation](https://github.com/microsoft/onnxruntime/blob/v1.20.1/onnxruntime/core/providers/cpu/ml/tree_ensemble_aggregator.h)
- [ONNX Runtime score transforms](https://github.com/microsoft/onnxruntime/blob/v1.20.1/onnxruntime/core/providers/cpu/ml/ml_common.h)
- [XGBoost model IO](https://xgboost.readthedocs.io/en/stable/tutorials/saving_model.html)
- [Nanopb 0.4.9.1](https://github.com/nanopb/nanopb/tree/0.4.9.1)
