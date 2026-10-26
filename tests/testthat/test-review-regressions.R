test_that("file-backed models detect replacement even when the schema is unchanged", {
  modelFile <- tempfile(fileext = ".onnx")
  savedFile <- tempfile(fileext = ".rds")
  on.exit(unlink(c(modelFile, savedFile)), add = TRUE)
  onnx_save(fixture_model(), modelFile)
  model <- onnx_load(modelFile, list(embed_raw_bytes = FALSE))
  saveRDS(model, savedFile)
  onnx_save(fixture_model(base = 0.7), modelFile)
  expect_error(onnx_predict(readRDS(savedFile), matrix(0, 1, 1)), "checksum")
  expect_error(onnx_save(model, tempfile()), "checksum")
})

test_that("oversized version identifiers cannot wrap into supported versions", {
  bytes <- fixture_model()@raw_bytes
  fields <- wire_fields(bytes)
  index <- which(vapply(fields, function(field) field$tag == 1, logical(1)))
  fields[[index]]$raw <- c(wire_varint(8), wire_varint(2^32 + 8))
  corruptedModel <- do.call(c, lapply(fields, "[[", "raw"))
  expect_error(cpp_open_model(corruptedModel), "range")
})

test_that("matrix inputs reject classed storage and missing column names", {
  model <- fixture_model()
  classedMatrix <- structure(matrix(1, 1, 1), class = c("custom", "matrix", "array"))
  expect_error(onnx_predict(model, classedMatrix), "plain|numeric")
  badNames <- matrix(1, 1, 1, dimnames = list(NULL, NA_character_))
  expect_error(onnx_predict(model, badNames), "names")
  expect_error(onnx_predict(model, matrix(1e100, 1, 1)), "float32 range")
})

test_that("native prediction wrappers retain empty result schemas", {
  model <- fixture_model()
  emptyData <- matrix(numeric(), 0, 1)
  expect_identical(levels(onnx_predict(model, emptyData, "class")$.pred_class),
                   model@class_levels)
  expect_identical(names(onnx_predict(model, emptyData)), c(".pred_absent", ".pred_present"))
})

test_that("signed integer labels and external class-score decisions are preserved", {
  fields <- wire_fields(fixture_model()@raw_bytes)
  external <- do.call(c, lapply(Filter(function(field) field$tag != 14, fields), "[[", "raw"))
  signedLabels <- c(as.raw(rep(255L, 9)), as.raw(1), wire_varint(1))
  signedModel <- WireReplaceAttribute(external, "classlabels_int64s",
                                     wire_message(8, signedLabels), 7)
  expect_identical(model_from_bytes(signedModel, "", TRUE)@class_levels, c("-1", "1"))
  rawModel <- WireReplaceAttribute(external, "post_transform",
                                   wire_message(4, charToRaw("NONE")), 3)
  rawModel <- WireReplaceAttribute(rawModel, "class_weights",
    wire_message(7, writeBin(c(0.9, 0.6, 0, 0, 0, 0), raw(), size = 4L, endian = "little")), 6)
  convertedModel <- model_from_bytes(rawModel, "", TRUE)
  expect_equal(onnx_predict(convertedModel, matrix(0, 1, 1), "raw"),
               matrix(c(0.9, 0.6), 1), tolerance = 1e-7)
  expect_identical(as.character(onnx_predict(convertedModel, matrix(0, 1, 1), "class")$.pred_class), "0")
})

test_that("attribute type declarations must match their operator fields", {
  bytes <- WireReplaceAttribute(fixture_model()@raw_bytes, "nodes_treeids",
    wire_message(8, do.call(c, lapply(c(0, 1, 1, 1), wire_varint))), 2)
  expect_error(cpp_open_model(bytes), "attribute type")
})

test_that("data-frame subclasses use column extraction rather than row dispatch", {
  skip_if_not_installed("data.table")
  MakeTable <- getExportedValue("data.table", "data.table")
  predictorData <- MakeTable(temperature = c(0, 1, NA_real_), extra = letters[1:3])
  expect_equal(onnx_predict(fixture_model(), predictorData),
               onnx_predict(fixture_model(), matrix(c(0, 1, NA_real_), ncol = 1)))
})
