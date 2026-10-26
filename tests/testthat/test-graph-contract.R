test_that("external metadata-free and unpacked ONNX graphs load correctly", {
  model <- fixture_model()
  fields <- wire_fields(model@raw_bytes)
  external <- do.call(c, lapply(Filter(function(field) field$tag != 14, fields), "[[", "raw"))
  external <- wire_edit_attribute(external, "nodes_nodeids", c(0, 0, 1, 2), unpacked = TRUE)
  loaded <- model_from_bytes(external, "", TRUE)
  expect_equal(loaded@source_class, "external")
  expect_equal(loaded@feature_names, "f0")
  expect_equal(loaded@class_levels, c("0", "1"))
  data <- matrix(c(0, 1, NA_real_), ncol = 1)
  expect_equal(onnx_predict(loaded, data, "raw"), onnx_predict(model, data, "raw"))
})

test_that("invalid tree topology and feature indices fail before traversal", {
  bytes <- fixture_model()@raw_bytes
  expect_error(cpp_open_model(wire_edit_attribute(bytes,
    "nodes_truenodeids", c(0, 99, 0, 0))), "child")
  expect_error(cpp_open_model(wire_edit_attribute(bytes,
    "nodes_nodeids", c(0, 0, 0, 2))), "Duplicate")
  expect_error(cpp_open_model(wire_edit_attribute(bytes,
    "nodes_featureids", c(0, 999, 0, 0))), "feature")
  expect_error(cpp_open_model(wire_edit_attribute(bytes,
    "nodes_missing_value_tracks_true", c(0, 2, 0, 0))), "missing")
  expect_error(cpp_open_model(wire_edit_attribute(bytes,
    "nodes_treeids", c(0, 1))), "lengths")
  expect_error(cpp_open_model(wire_edit_attribute(bytes,
    "nodes_truenodeids", c(0, 0, 0, 0))), "unreachable|root|Cyclic")
})

test_that("unsupported graph operators cannot masquerade as trees", {
  bytes <- wire_edit_node(fixture_model()@raw_bytes, function(node) {
    index <- which(vapply(node, function(field) field$tag == 4, logical(1)))
    node[[index]]$raw <- wire_message(4, charToRaw("MatMul"))
    node
  })
  expect_error(cpp_open_model(bytes), "Unsupported operator")
})

test_that("logistic regression uses a portable explicit graph activation", {
  model <- fixture_model("reg:logistic")
  expect_equal(onnx_inspect(model)$model$nodes, 2L)
  expect_equal(onnx_predict(model, matrix(c(0, 2, NA_real_), ncol = 1))$.pred,
    plogis(qlogis(0.3) + c(-0.7, 1.1, -0.7)), tolerance = 2e-7)
})
