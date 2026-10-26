# tidyonnx 0.1.1

* `onnx_convert()` now dispatches on fitted XGBoost, parsnip, and workflow objects.
  Converted prediction bundles retain preprocessing and original outcome order.
* `predict()` and `onnx_predict()` support converted bundles. RDS persistence
  preserves their R preprocessing; graph-only saving rejects bundles explicitly.
* Early-stopped conversions honor the saved best iteration; an explicit
  iteration_range = "all" setting exports the complete stored ensemble.
* File-backed restoration verifies model identity with a saved checksum.
  Staged file replacement avoids truncating an existing destination.
* Serialization avoids duplicate graph decoding and repeated exact-capacity
  allocations. Automatic worker detection is cached and small batches use fewer
  threads.
* Graph decoding checks message wire types, integer overflow, and declared
  attribute types. Signed integer class labels are decoded correctly.
* External classifier class decisions use the largest class score. Converted
  binary logistic models retain their positive-class threshold behavior.
* Public and internal R functions have roxygen2 source documentation. The README
  includes modeldata examples with and without tidymodels, lifecycle and CI
  badges, and the package citation names João B. G. de Brito.

# tidyonnx 0.1.0

* Initial native ONNX serialization and CPU inference for numerical XGBoost
  ensembles, with S7 ownership, cpp11 bindings, and bundled wire-format support.
