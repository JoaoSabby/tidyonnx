test_that("external metadata-free and unpacked ONNX graphs load correctly", {
  model <- fixture_model()
  fields <- wire_fields(model@raw_bytes)
  external <- do.call(c, lapply(Filter(function(field) field$tag != 14, fields), "[[", "raw"))
  external <- wire_edit_attribute(external, "nodes_nodeids", c(0, 0, 1, 2), unpacked = TRUE)
  loaded <- tidyonnx:::model_from_bytes(external, "", TRUE)
  expect_equal(loaded@source_class, "external")
  expect_equal(loaded@feature_names, "f0")
  expect_equal(loaded@class_levels, c("0", "1"))
  data <- matrix(c(0, 1, NA_real_), ncol = 1)
  expect_equal(onnx_predict(loaded, data, "raw"), onnx_predict(model, data, "raw"))
})

test_that("invalid tree topology and feature indices fail before traversal", {
  bytes <- fixture_model()@raw_bytes
  expect_error(tidyonnx:::cpp_open_model(wire_edit_attribute(bytes,
    "nodes_truenodeids", c(0, 99, 0, 0))), "child")
  expect_error(tidyonnx:::cpp_open_model(wire_edit_attribute(bytes,
    "nodes_nodeids", c(0, 0, 0, 2))), "Duplicate")
  expect_error(tidyonnx:::cpp_open_model(wire_edit_attribute(bytes,
    "nodes_featureids", c(0, 999, 0, 0))), "feature")
  expect_error(tidyonnx:::cpp_open_model(wire_edit_attribute(bytes,
    "nodes_missing_value_tracks_true", c(0, 2, 0, 0))), "missing")
  expect_error(tidyonnx:::cpp_open_model(wire_edit_attribute(bytes,
    "nodes_treeids", c(0, 1))), "lengths")
  expect_error(tidyonnx:::cpp_open_model(wire_edit_attribute(bytes,
    "nodes_truenodeids", c(0, 0, 0, 0))), "unreachable|root|Cyclic")
})

test_that("unsupported graph operators cannot masquerade as trees", {
  bytes <- wire_edit_node(fixture_model()@raw_bytes, function(node) {
    index <- which(vapply(node, function(field) field$tag == 4, logical(1)))
    node[[index]]$raw <- wire_message(4, charToRaw("MatMul"))
    node
  })
  expect_error(tidyonnx:::cpp_open_model(bytes), "Unsupported operator")
})

test_that("logistic regression uses a portable explicit graph activation", {
  model <- fixture_model("reg:logistic")
  expect_equal(onnx_inspect(model)$model$nodes, 2L)
  expect_equal(onnx_predict(model, matrix(c(0, 2, NA_real_), ncol = 1))$.pred,
    plogis(qlogis(0.3) + c(-0.7, 1.1, -0.7)), tolerance = 2e-7)
})

test_that("optional node hit rates require one finite FLOATS value per node", {
  bytes <- fixture_model()@raw_bytes
  openModel <- getFromNamespace("cpp_open_model", "tidyonnx")

  # Encode an optional attribute independently of the native serializer
  WithHitRates <- function(payload, type){
    wire_edit_node(bytes, function(node){
      attribute <- c(wire_message(1, charToRaw("nodes_hitrates")), payload,
        wire_varint(20 * 8), wire_varint(type))
      c(node, list(list(raw = wire_message(5, attribute))))
    })
  }

  finiteRates <- writeBin(c(1, 0.5, 0.25, 0.25), raw(), size = 4L, endian = "little")
  nonfiniteRates <- writeBin(c(1, 0.5, NaN, Inf), raw(), size = 4L, endian = "little")

  expect_type(openModel(WithHitRates(wire_message(7, finiteRates), 6)), "externalptr")
  expect_error(openModel(WithHitRates(wire_message(7, finiteRates[1:12]), 6)),
    "nodes_hitrates length")
  expect_error(openModel(WithHitRates(wire_message(8, as.raw(c(1, 1, 1, 1))), 7)),
    "nodes_hitrates must have type FLOATS")
  scalarRates <- do.call(c, lapply(seq(1L, 13L, by = 4L), function(offset){
    c(as.raw(2 * 8 + 5), finiteRates[offset + 0:3])
  }))
  expect_error(openModel(WithHitRates(scalarRates, 6)), "nodes_hitrates must use repeated float")

  expect_error(openModel(WithHitRates(wire_message(7, nonfiniteRates), 6)),
    "Nonfinite ONNX nodes_hitrates")
})

test_that("trailing Sigmoid permits standard metadata but rejects attributes", {
  model <- fixture_model("reg:logistic")
  fromBytes <- getFromNamespace("model_from_bytes", "tidyonnx")
  openModel <- getFromNamespace("cpp_open_model", "tidyonnx")

  # Attach NodeProto overload and metadata fields to the second graph node
  metadataEntry <- c(wire_message(1, charToRaw("source")), wire_message(2, charToRaw("external")))
  annotated <- wire_edit_node(model@raw_bytes, function(node){
    c(node, list(list(raw = wire_message(8, raw())),
      list(raw = wire_message(9, metadataEntry))))
  }, node = 2L)

  data <- matrix(c(0, 2, NA_real_), ncol = 1)
  expect_identical(onnx_predict(fromBytes(annotated, "", TRUE), data), onnx_predict(model, data))

  invalid <- wire_edit_node(annotated, function(node){
    c(node, list(list(raw = wire_message(5, raw()))))
  }, node = 2L)
  expect_error(openModel(invalid), "Sigmoid does not support ONNX attributes.", fixed = TRUE)
})

test_that("external batch shapes accept positive and unspecified dimensions", {
  model <- fixture_model()
  fields <- Filter(function(field) field$tag != 14, wire_fields(model@raw_bytes))
  external <- do.call(c, lapply(fields, "[[", "raw"))
  data <- matrix(rep(c(0, 2), 5L), ncol = 1L)
  path <- tempfile(fileext = ".onnx")
  on.exit(unlink(path), add = TRUE)

  # Rewrite the first dimension of the selected graph inputs or outputs
  SetBatch <- function(graph, tags, batch){
    for(index in seq_along(graph)){
      if(!graph[[index]]$tag %in% tags) next

      value <- wire_fields(graph[[index]]$value)
      type <- wire_fields(value[[2L]]$value)
      tensor <- wire_fields(type[[1L]]$value)
      shape <- wire_fields(tensor[[2L]]$value)
      shape[[1L]]$raw <- wire_message(1, batch)

      tensor[[2L]]$raw <- wire_message(2, do.call(c, lapply(shape, "[[", "raw")))
      type[[1L]]$raw <- wire_message(1, do.call(c, lapply(tensor, "[[", "raw")))
      value[[2L]]$raw <- wire_message(2, do.call(c, lapply(type, "[[", "raw")))
      graph[[index]]$raw <- wire_message(graph[[index]]$tag,
        do.call(c, lapply(value, "[[", "raw")))
    }

    graph
  }

  # A static batch of ten and an empty Dimension both preserve inference
  for(batch in list(as.raw(c(8, 10)), raw())){
    bytes <- WireEditGraph(external, function(graph) SetBatch(graph, c(11, 12), batch))
    writeBin(bytes, path)
    loaded <- onnx_load(path)
    expect_identical(loaded@source_class, "external")
    expect_identical(onnx_predict(loaded, data, type = "raw"),
      onnx_predict(model, data, type = "raw"))
  }

  # Exercise input and output validation independently for zero and signed -1
  for(tag in c(11, 12)){
    for(batch in list(as.raw(c(8, 0)), as.raw(c(8, rep(255, 9L), 1)))){
      bytes <- WireEditGraph(external, function(graph) SetBatch(graph, tag, batch))
      writeBin(bytes, path)
      expect_error(onnx_load(path), "batch size|output schema|negative ONNX identifier")
    }
  }
})
