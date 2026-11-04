# Architecture decisions for 0.2.0

The implementation evolves the 0.1.0 checkout at d8a77cb rather than replacing
its converter. The execution boundary is now ONNX Runtime 1.31.1 through its
C API, with cpp11 as the only R/native bridge. There is no evaluator fallback.

## Installation and ownership

Configure scripts run an R installer against a fixed platform/hash manifest.
The matching release headers are used for compilation; the private shared
library, version, archive digest, binary digest, license and notices are
installed under the package. Generated headers and binaries are excluded from
the source archive and are not committed. Exact release and API version checks
precede session creation. Unsupported architectures fail explicitly.

A shared native library owner retains the C API and OrtEnv. Every native
session owns a shared reference, so session destruction always precedes library
unloading. Type information, session options, metadata and inference values
have scope guards. No R API call occurs on runtime worker threads. Namespace
loading checks the installed digest; actual library loading is deferred until
first session creation to avoid locking staged Windows installation paths.

## Serialization and artifact

The existing XGBoost tree extraction, objective table, intercept mathematics,
Nanopb encoding and explicit score strategies remain shared. The bounded
parser is isolated as a serializer validator and a malformed-tree diagnostic.
It is not the external loader or an inference engine. The former C evaluator
is no longer compiled. The ONNX file contains feature/class/outcome metadata
and can execute independently of R using its declared prepared inputs.

The S7 artifact retains embedded bytes or a documented byte-identical backing
file, generic runtime input/output metadata, optional recognized task metadata
and an external-pointer cache. RDS restoration checks the source SHA-256 and
recreates the session. Unrecognized external graphs have no guessed features,
class labels or tree counts. Saving stages exact bytes and preserves a backup
until replacement succeeds; recovery failures identify the original backup.

## Tensor and tidy interfaces

The named tensor interface supports dense float32/float64/int32/int64 values.
It validates names, shapes, symbolic dimension agreement, precision and size
before creating native tensors. It explicitly transposes storage order for
arbitrary supported rank. Outputs preserve names and dimension axes. Int64
values outside exact R double range fail rather than lose information.
Unbounded data-dependent outputs and unsupported value categories fail.
A per-tensor bound does not guarantee a total runtime workspace limit.

Tidy predictions sit above named tensor inference and require a recognized
tabular contract. The existing raw-vector/matrix result is retained. Binary
class ties preserve the package rule; graph labels are exposed separately by
onnx_run and verified independently in tests. One shared converter can encode
parsnip's first-level-positive convention without changing direct conversion's
numeric class-ID convention.

## Workflows and exclusions

A narrow S3 subclass delegates one call to the public fit generic, extracts the
fitted engine and mold using public workflow accessors, validates the prepared
contract and probes numerical parity, then attaches the S7 artifact. Ordinary
workflow prediction retains its recipe. Unsupported conversions fail the fit.
No private workflow extension hooks, recipe export, tuning or resampling hooks
are used. Only supported XGBoost engines convert; only tested tensor mappings
execute through the R interface. GPU and arbitrary ONNX support are not claimed.

## Primary references

- [Fixed runtime release](https://github.com/microsoft/onnxruntime/releases/tag/v1.31.1)
- [Matching C API](https://github.com/microsoft/onnxruntime/blob/v1.31.1/include/onnxruntime/core/session/onnxruntime_c_api.h)
- [Public workflow extraction](https://workflows.tidymodels.org/reference/extract-workflow.html)
- [Public fit generic](https://generics.r-lib.org/reference/fit.html)
- [XGBoost model IO](https://xgboost.readthedocs.io/en/stable/tutorials/saving_model.html)
