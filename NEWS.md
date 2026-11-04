# tidyonnx 0.2.0

- Use private, checksum-verified ONNX Runtime 1.31.1 CPU sessions through the C API.
- Add named numeric tensor execution and generic runtime metadata inspection.
- Preserve six XGBoost objective paths and raw tabular output compatibility.
- Add outcome metadata and direct workflow ONNX artifacts with prepared inputs.
- Detect changed backing files and recover existing destinations on save failure.
- Enable R byte compilation and configurable safe native optimization.
- Reject operation-specific settings that were previously validated but ignored.
- Keep existing Rd documentation unchanged in this implementation phase.
# tidyonnx 0.1.0

* Added five public ONNX functions with S7 model objects and tibble outputs.
* Added native conversion of six numerical XGBoost gbtree objectives.
* Added self-contained Nanopb serialization and C tree-ensemble inference.
* Added named-feature alignment, integer/NA handling, bounded OpenMP workers,
  and transparent native-session restoration after RDS persistence.
* Added explicit graph-subset validation and independent runtime validation tools.
