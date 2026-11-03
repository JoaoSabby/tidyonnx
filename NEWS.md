# tidyonnx 0.1.0

* Added five public ONNX functions with S7 model objects and tibble outputs.
* Added native conversion of numerical XGBoost gbtree classification objectives.
* Added self-contained Nanopb serialization and C tree-ensemble inference.
* Added named-feature alignment, integer/NA handling, bounded OpenMP workers,
  and transparent native-session restoration after RDS persistence.
* Added explicit graph-subset validation and independent runtime validation tools.

## S7 architecture and source adapters

* Report XGBoost regression and elastic net conversion as not implemented,
  including direct, parsnip, and workflow inputs.
* Match the source R complementary probability arithmetic in formatted binary
  predictions while preserving graph-native raw outputs.

* Use S7 dispatch for all public operations and standard R compatibility methods.
* Prefix private R bindings, generated native wrappers, and test helpers with
  `onnx_internal_`; preserve the `.onLoad` lifecycle hook.
* Convert supported fitted source models only. Unrecognized formats now emit an
  informative message and return invisible NULL without modifying destinations.
* Add fitted parsnip and workflow adapters with class-encoding validation,
  persistent class presentation order, and retained workflow preprocessing in RDS.
* Reject standalone ONNX export of workflow preprocessing and conversion of
  early-stopped models whose effective tree range cannot yet be serialized.
* Remove R for loops from implementation, tests, and reference validation;
  add an executable native-only policy audit to cross-platform CI.
