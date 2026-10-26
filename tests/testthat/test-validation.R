test_that("input contracts fail before inference", {
  model <- fixture_model()
  for (input in list(NULL, list(temperature = 1), data.frame(x = 1),
      data.frame(temperature = "1"), data.frame(temperature = factor("1")),
      data.frame(temperature = as.Date("2026-01-01")), matrix("1", 1, 1),
      matrix(1, 1, 2), matrix(Inf, 1, 1))) {
    expect_error(onnx_predict(model, input))
  }
  expect_error(onnx_predict(model, matrix(1, 1, 1), type = c("prob", "class")), "type")
  expect_error(onnx_predict(model, matrix(1, 1, 1), type = NA_character_), "type")
  expect_error(onnx_predict(list(), matrix(1, 1, 1)), "object")
  expect_error(predict(model, matrix(1, 1, 1), unknown = 1), "Unused")
})

test_that("unsupported tuning is rejected explicitly", {
  for (params in list(list(threads = 1), list(intra_op_threads = -1),
      list(intra_op_threads = 1.5), list(intra_op_threads = NA),
      list(execution_provider = "cuda"), list(float_precision = "float64"),
      list(inter_op_threads = 2), list(graph_opt_level = "extended"),
      list(embed_raw_bytes = 1), list(target_opset = 17),
      list(class_levels = c("same", "same")), list(1), c(a = 1))) {
    expect_error(validate_onnx_params(params))
  }
  expect_error(validate_onnx_params(structure(list(1, 2), names = c("ir_version", "ir_version"))))
})

test_that("malformed protobuf and truncated models never publish a session", {
  model <- fixture_model()
  for (bytes in list(raw(), as.raw(c(0x3a, 0xff, 0xff)), as.raw(c(0, 0)),
      as.raw(c(0x08, 0x80)), as.raw(rep(0xff, 20)))) {
    expect_error(cpp_open_model(bytes))
  }
  for (size in unique(as.integer(seq(1, length(model@raw_bytes) - 1, length.out = 25)))) {
    expect_error(cpp_open_model(model@raw_bytes[seq_len(size)]))
  }
  expect_false(cpp_session_alive(NULL))
  expect_error(cpp_model_info(NULL), "session")
})

test_that("model and file contracts are validated", {
  expect_error(onnx_load(tempfile()), "missing")
  expect_error(onnx_load(character()), "file")
  expect_error(onnx_save(fixture_model(), tempdir()), "file")
  expect_error(onnx_inspect(NULL), "object")
  expect_error(fixture_model(base = 1), "strictly")
  expect_error(fixture_model(objective = "count:poisson"), "Unsupported")
})
