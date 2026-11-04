test_that("external metadata-free and unpacked ONNX graphs load correctly", {
  model <- onnx_internal_fixture_model()
  fields <- onnx_internal_wire_fields(model@raw_bytes)
  external <- do.call(c, lapply(Filter(function(field) field$tag != 14, fields), "[[", "raw"))
  external <- onnx_internal_wire_edit_attribute(external, "nodes_nodeids", c(0, 0, 1, 2), unpacked = TRUE)
  loaded <- tidyonnx:::onnx_internal_model_from_bytes(external, "", TRUE)
  expect_equal(loaded@source_class, "external")
  expect_identical(loaded@feature_names, character())
  expect_identical(loaded@class_levels, character())
  data <- matrix(c(0, 1, NA_real_), ncol = 1)
  expect_equal(onnx_run(loaded, list(features = data))$probabilities,
    onnx_predict(model, data, "raw"))
  expect_error(onnx_predict(loaded, data), "No recognized tidy")
})

test_that("invalid tree topology and feature indices fail before traversal", {
  bytes <- onnx_internal_fixture_model()@raw_bytes
  expect_error(tidyonnx:::onnx_internal_validate_tree(onnx_internal_wire_edit_attribute(bytes,
    "nodes_truenodeids", c(0, 99, 0, 0))), "child")
  expect_error(tidyonnx:::onnx_internal_validate_tree(onnx_internal_wire_edit_attribute(bytes,
    "nodes_nodeids", c(0, 0, 0, 2))), "Duplicate")
  expect_error(tidyonnx:::onnx_internal_validate_tree(onnx_internal_wire_edit_attribute(bytes,
    "nodes_featureids", c(0, 999, 0, 0))), "feature")
  expect_error(tidyonnx:::onnx_internal_validate_tree(onnx_internal_wire_edit_attribute(bytes,
    "nodes_missing_value_tracks_true", c(0, 2, 0, 0))), "missing")
  expect_error(tidyonnx:::onnx_internal_validate_tree(onnx_internal_wire_edit_attribute(bytes,
    "nodes_treeids", c(0, 1))), "lengths")
  expect_error(tidyonnx:::onnx_internal_validate_tree(onnx_internal_wire_edit_attribute(bytes,
    "nodes_truenodeids", c(0, 0, 0, 0))), "unreachable|root|Cyclic")
})

test_that("unsupported graph operators cannot masquerade as trees", {
  bytes <- onnx_internal_wire_edit_node(onnx_internal_fixture_model()@raw_bytes, function(node) {
    index <- which(vapply(node, function(field) field$tag == 4, logical(1)))
    node[[index]]$raw <- onnx_internal_wire_message(4, charToRaw("MatMul"))
    node
  })
  expect_error(tidyonnx:::onnx_internal_open_model(bytes), "ONNX Runtime")
})

test_that("logistic regression uses a portable explicit graph activation", {
  model <- onnx_internal_fixture_model("reg:logistic")
  expect_equal(onnx_inspect(model)$model$nodes, 2L)
  expect_equal(onnx_predict(model, matrix(c(0, 2, NA_real_), ncol = 1))$.pred,
    plogis(qlogis(0.3) + c(-0.7, 1.1, -0.7)), tolerance = 2e-7)
})
