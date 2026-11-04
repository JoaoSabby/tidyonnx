# Software quality and implementation decisions

## Review baseline and authority

This review starts from commit d8a77cbf6bfe681fa43760e69e1e882053bed546.
The implementation follows the user's approved functional, naming, object-system,
native-runtime, and documentation requirements. Package source and documentation
use formal technical English. This document distinguishes accepted decisions from
limitations and future work; a recommendation is not a claim of completed support.

## 1. Public interface and responsibilities

The package exports exactly five S7 generics:

| Operation | Input | Result | Responsibility |
| --- | --- | --- | --- |
| `onnx_convert()` | Supported fitted source model | S7 ONNX model | Identify and serialize the source model |
| `onnx_save()` | Source model or ONNX model | Invisible normalized path | Persist a supported graph |
| `onnx_load()` | ONNX path | S7 ONNX model | Validate and open graph bytes |
| `onnx_predict()` | ONNX model or path, predictor data | Tibble or raw numerical output | Apply retained preprocessing and evaluate |
| `onnx_inspect()` | ONNX model or path | List of tibbles | Describe graph and engine capabilities |

Direct calls do not require attaching tidyverse or tidymodels. Tibble is a required
dependency because structured predictions use tibbles. The package does not claim
independence from every individual tidyverse package.

The existing argument distinction is retained: `model` identifies conversion or
persistence input, while `object` identifies an inference or inspection object.
Changing those argument names would break named calls without improving dispatch.

## 2. Internal naming and organization

Every private R function and constructor binding starts with `onnx_internal_`.
The `.onLoad` hook retains the spelling required by R. S7 registers methods for
standard R generic functions without exporting additional user functions.

Each handwritten R source file contains one principal top-level function or
generic. `R/cpp11.R` is a generated bridge file containing its related wrappers;
regeneration preserves their prefix because their registered native entry points
carry that prefix. Test fixture helpers follow the same private naming rule.

The S7 object's class identity remains `tidyonnx::onnx_model`; its private
constructor binding is `onnx_internal_model`. The type identity is not a public
function name. Native algorithm functions retain their language-specific API.

## 3. S7 object and dispatch contracts

All public operations dispatch through S7. Conversion registers methods for
`xgb.Booster`, parsnip `model_fit`, and fitted `workflow` objects. An unsupported
class reaches a common fallback instead of being interpreted as model data.

S7 interoperates with those upstream S3 classes; it does not redefine classes
owned by XGBoost or tidymodels. The model's properties, invariants, and lifecycle
remain governed by its S7 class. Pure validation and serialization helpers remain
ordinary functions when class dispatch would add no useful behavior.

`onnx_convert()` no longer accepts an ONNX object. Saving an already converted
object remains supported through a separate persistence path.

## 4. Unsupported objects and failure semantics

An unrecognized class or unsupported source-model configuration emits a message
containing the received class, the reason when available, and implemented source
formats. It returns `invisible(NULL)`. This ends the function call, not the calling
R script. The caller can inspect `is.null()` before continuing a pipeline.

Saving propagates that result before creating or replacing the destination.
Invalid caller parameters, corrupt model structures, invalid predictor data,
unreadable files, and native failures still raise errors. Suppressing those errors
would hide failures unrelated to source-format recognition.

## 5. Model coverage and effort beyond binary logistic classification

The native baseline contains six objective paths. The approved public conversion
scope now accepts classification objectives only: XGBoost regression conversion
and elastic net conversion must report not implemented and return invisible NULL.
Native loading of already-created supported ONNX regressor graphs remains
available; it is a separate capability from source-model conversion.

| Objective | Existing mechanism | Incremental engineering effort |
| --- | --- | --- |
| `binary:logistic` | Explicit complementary class scores | Baseline support and portability tests |
| `binary:logitraw` | Regression-shaped raw margin output | Low: retain numeric-response semantics |
| `reg:squarederror` | Public conversion not implemented | Message and NULL; native graph evaluation retained |
| `reg:logistic` | Public conversion not implemented | Message and NULL; native graph evaluation retained |
| `multi:softprob` | Tree-to-class routing and softmax | Moderate validation burden: labels, vector intercepts, ties |
| `multi:softmax` | Same probability graph with argmax formatting | Moderate validation burden: clarify output semantics |

These are qualitative assessments of existing paths, not elapsed-time estimates.
Elastic net, including glmnet models supplied directly or through parsnip and
workflows, also returns message and NULL. No ONNX prediction is fabricated for an
unsupported model. Numerical classification gbtree models and parallel
trees remain supported. DART, linear boosters, categorical splits, vector leaves,
multiple regression targets, and arbitrary custom objectives remain unsupported.
Early-stopped models are rejected until effective tree-range serialization exists;
exporting all trees can differ from the source's default prediction range.

## 6. Tidymodels placement: after fitting

Conversion occurs after `fit()`, outside model training and tuning. It is not a
recipe step and does not register a new parsnip training engine. The trained
workflow is passed directly to `onnx_convert()`.

A workflow adapter extracts the fitted parsnip model and the fitted hardhat
blueprint. The native engine is serialized; the blueprint remains in the R object
and transforms new raw predictors through `hardhat::forge()` before inference.
The workflow's fitted predictor names cannot be renamed during conversion.

A direct parsnip adapter exports the fitted engine. Its prediction input must
already match the engine's prepared predictor schema. Passing a full workflow is
the supported route for retaining recipes, formula preprocessing, and factor
encoding. A naked extracted engine never implies retained preprocessing.

The default binary parsnip event is the first outcome level, encoded as 1. Native
class mapping and formatted output ordering are handled separately. Explicit
presentation-order metadata survives ONNX persistence and is validated as a
permutation of the graph's class labels. Both literal `event_level = "first"` and
`"second"` settings are supported. Unresolved expressions are rejected: the
installed parsnip prediction postprocessor inspects the stored argument expression
rather than evaluating it. Resolving that expression differently could change
the fitted object's prediction semantics.

## 7. Persistence and deployment boundaries

Ordinary ONNX models support `.onnx` persistence and native inference independent
of tidymodels packages. Workflow blueprints are R objects, not serialized ONNX
operators. A complete workflow-derived conversion uses `saveRDS()`/`readRDS()`;
its inference still needs hardhat and packages required by its preprocessing.

Standalone ONNX export of a workflow-derived result is rejected before writing
the destination. Users who intentionally want an engine-only graph can extract
and convert the fitted engine and supply identically prepared predictors. The
package never silently discards the workflow's preprocessing.

Native pointers are restored from embedded bytes after RDS loading. File-backed
restoration requires the original file and checks the feature/task/class schema.
This is schema validation, not a cryptographic identity guarantee.

## 8. Dependencies and runtime policy

Installation, conversion, inference, tests, and development validation use R,
C, and C++. The runtime is self-contained and uses cpp11 plus vendored Nanopb.
No alternative interpreter bridge or external inference service is introduced.

XGBoost, workflows, parsnip, hardhat, recipes, and rlang are optional packages.
Namespace availability is checked only on applicable adapter paths. `withr` is
not needed for namespace checks; no temporary process configuration is required.
`collapse` and `purrr` are not added merely to replace small base-R mappings.
Base `lapply()` and `vapply()` satisfy those independent traversals with fewer
dependencies. Add another library only when measured work justifies it.

## 9. Performance and functional R

Executable R `for` loops are prohibited throughout source, tests, and tools.
Independent operations use functional mapping; numerical column and matrix work
uses vectorized primitives. Native traversal uses C/C++ loops, which are permitted
and necessary for branch-dependent tree evaluation. Existing bounded wire-test
parsers retain sequential `while`/`repeat` constructs; those were not prohibited.

Functional mapping is not itself proof of SIMD execution or greater speed.
The implementation preserves borrowed input buffers and avoids full row-major
copies in direct inference. Workflow preprocessing has its own allocations and
cost. No unmeasured claim of maximum speed or zero allocation is made.

## 10. Readability, comments, and clean code

Handwritten scripts contain orienting comments. Function comments describe their
responsibility; local comments explain encoding, persistence, and resource choices.
Comments and names use English. Documentation remains maintained in Rd files,
consistent with the repository's existing documentation process.

Validation precedes native allocation or destination writes where possible.
Conversion dispatch, source extraction, source support checks, serialization,
prediction preparation, and persistence are separate responsibilities.

## 11. Verification and evidence

The behavioral suite covers native graph validation, malformed inputs, missing
values, feature alignment, objective equivalence, persistence, and thread-setting
invariance. New tests cover S7 dispatch, private naming, informative unsupported
returns, recipes, binary label encoding, multiclass workflows, RDS restoration,
and persistence of class presentation order. The expanded compiler matrix covers
48 source scenarios: three seeds, two model families, binary/regression tasks,
and direct, parsnip, formula-workflow, and recipe-workflow routes. Supported binary
XGBoost cases require exact full-table prediction equality; XGBoost regression
and elastic net require the documented unsupported result. Precise Intel AVX-512
builds are mandatory checks; fast-math is a separate experiment that is rejected
if it changes results or input semantics.

`tools/check-policy.R` checks runtime bridges, disallowed source-file extensions,
R loop syntax, and the presence of script comments. Cross-platform CI runs that
audit and package checks with the optional workflow dependencies installed.
Current-run validation results are recorded in `VALIDATION.md`; old evidence
files remain historical evidence and do not prove the current revision passes.

## 12. Remaining extensions

Future work includes ONNX serialization of selected preprocessing operations,
early-stopping tree ranges, additional model families, and dynamic parsnip
event expressions. Each requires explicit semantic contracts, native support where
needed, and independent equivalence tests before being listed as implemented.

## Primary design references

- [S7 package integration](https://rconsortium.github.io/S7/articles/packages.html)
- [S7 generic functions](https://rconsortium.github.io/S7/reference/new_generic.html)
- [S7 method registration](https://rconsortium.github.io/S7/reference/method-set.html)
- [Workflow extraction and preprocessing boundaries](https://workflows.tidymodels.org/reference/extract-workflow.html)

## 13. Native compiler profiles and observed performance

The adapted Intel profile uses native architecture/tuning and generic tool paths.
It retains an aggressive arithmetic mode and a separately measured strict control.
Compiler selection requires both functional correctness and exact source-probability
checks. A faster result from a numerically rejected profile is diagnostic only.
The original site-specific configuration remains local; native binaries are tied
to the compilation host's supported instruction set.

The completed benchmark covers 28 cases, 21 samples per case/profile, and 1,764
raw timing samples. GCC, Intel native fast, and Intel native strict each passed
184 package expectations. GCC and Intel strict matched all 400,000 saved formatted
probability values; the aggressive profile changed 37,404 values and was rejected.
For 100,000 rows and 256 trees, GCC probability-output medians were 0.711 s with
one worker and 0.461 s with two; Intel strict medians were 0.773 s and 0.534 s.
These are hosted AMD EPYC measurements, not a general vendor ranking or a result
for the BrotServer Xeon. VALIDATION.md links the tested revision, full samples,
compiler commands, artifact fingerprints, and acceptance details.
