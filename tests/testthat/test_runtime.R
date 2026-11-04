# Independent wire fixtures exercise non-tree tensors without using the model serializer.
onnx_internal_tensor_fixture <- function(type = 1L, shape = c(NA, 2), operator = "Identity",
    two_inputs = FALSE, output_type = type, output_shape = shape,
    output_sequence = FALSE) {
  # Explicit symbolic batch names require compatible batch dimensions across inputs.
  onnx_internal_value <- function(name, element, dimensions, sequence = FALSE) {
    dims <- lapply(dimensions, function(dimension) {
      payload <- if (is.na(dimension)) onnx_internal_wire_message(2L, charToRaw("batch")) else
        c(onnx_internal_wire_varint(8), onnx_internal_wire_varint(dimension))
      onnx_internal_wire_message(1, payload)
    })
    tensor <- c(onnx_internal_wire_varint(8), onnx_internal_wire_varint(element),
      onnx_internal_wire_message(2, do.call(c, dims)))
    type <- onnx_internal_wire_message(1, tensor)
    if (sequence) type <- onnx_internal_wire_message(4, onnx_internal_wire_message(1, type))
    c(onnx_internal_wire_message(1, charToRaw(name)), onnx_internal_wire_message(2, type))
  }
  node <- c(onnx_internal_wire_message(1, charToRaw("x")),
    if (two_inputs) onnx_internal_wire_message(1, charToRaw("y")),
    onnx_internal_wire_message(2, charToRaw("result")), onnx_internal_wire_message(4, charToRaw(operator)))
  graph <- c(onnx_internal_wire_message(1, node), onnx_internal_wire_message(2, charToRaw("external_fixture")),
    onnx_internal_wire_message(11, onnx_internal_value("x", type, shape)),
    if (two_inputs) onnx_internal_wire_message(11, onnx_internal_value("y", type, shape)),
    onnx_internal_wire_message(12, onnx_internal_value("result", output_type, output_shape,
      output_sequence)))
  bytes <- c(onnx_internal_wire_varint(8), onnx_internal_wire_varint(8), onnx_internal_wire_message(7, graph),
    onnx_internal_wire_message(8, c(onnx_internal_wire_varint(16), onnx_internal_wire_varint(18))))
  tidyonnx:::onnx_internal_model_from_bytes(bytes, "", TRUE)
}

test_that("generic tensor inference preserves names, ranks, values and R storage", {
  for (type in c(1L, 11L, 6L, 7L)) {
    model <- onnx_internal_tensor_fixture(type, shape = c(2, 3, 4))
    x <- array(as.integer(1:24), dim = c(2, 3, 4))
    output <- onnx_run(model, list(x = x))
    expect_named(output, "result")
    expect_identical(dim(output$result), dim(x))
    expect_equal(as.numeric(output$result), as.numeric(x))
    expect_type(output$result, if (type == 6L) "integer" else "double")
  }
  scalar <- onnx_internal_tensor_fixture(11L, numeric())
  expect_identical(onnx_run(scalar, list(x = 3.25))$result, 3.25)
  vector <- onnx_internal_tensor_fixture(11L, NA_real_)
  expect_identical(dim(onnx_run(vector, list(x = 1:3))$result), 3L)
})

test_that("named multi-input tensors check shared dimensions and supported storage", {
  model <- onnx_internal_tensor_fixture(operator = "Add", two_inputs = TRUE)
  x <- matrix(1:6, 3, 2)
  expect_equal(onnx_run(model, list(y = x, x = x))$result, x * 2)
  expect_error(onnx_run(model, list(x = x)), "names")
  expect_error(onnx_run(model, list(x = x, wrong = x)), "names")
  expect_error(onnx_run(model, structure(list(x, x), names = c("x", "x"))), "uniquely")
  expect_error(onnx_run(model, list(x = x, y = matrix(1, 2, 2))), "dimension")
  expect_error(onnx_run(model, list(x = x, y = matrix(1, 3, 3))), "shape")
  expect_error(onnx_run(model, list(x = x, y = 1:6)), "rank")
  expect_error(onnx_run(model, list(x = x, y = matrix(Inf, 3, 2))), "Infinite")
  expect_error(onnx_run(model, list(x = x, y = matrix("a", 3, 2))), "numeric")
  expect_error(onnx_run(model, list(x = x, y = matrix(1e100, 3, 2))), "float32")
})

test_that("missing floats are explicit and integer precision is never silently lost", {
  model <- onnx_internal_tensor_fixture()
  x <- matrix(c(1, NA, NaN, 4), 2, 2)
  expect_equal(is.na(onnx_run(model, list(x = x))$result), is.na(x))
  for (type in c(6L, 7L)) {
    integer <- onnx_internal_tensor_fixture(type)
    expect_error(onnx_run(integer, list(x = x)), "non-missing")
    expect_error(onnx_run(integer, list(x = matrix(1.5, 2, 2))), "exact")
  }
  integer <- onnx_internal_tensor_fixture(7L)
  expect_error(onnx_run(integer, list(x = matrix(2^53 + 2, 2, 2))), "exact base R")
  expect_equal(onnx_run(integer, list(x = matrix(2^53, 2, 2)))$result,
    matrix(2^53, 2, 2))
  expect_error(onnx_run(onnx_internal_tensor_fixture(6L),
    list(x = matrix(-2^31, 2, 2))), "base R")
  sum <- onnx_internal_tensor_fixture(7L, operator = "Add", two_inputs = TRUE)
  expect_error(onnx_run(sum, list(x = matrix(2^53, 2, 2), y = matrix(1, 2, 2))),
    "int64 output")
})

test_that("unsupported values remain inspectable but cannot be coerced by onnx_run", {
  string <- onnx_internal_tensor_fixture(8L)
  expect_match(onnx_inspect(string)$inputs$element_type, "unsupported")
  expect_error(onnx_run(string, list(x = matrix(1, 2, 2))), "Unsupported")
  sequence <- onnx_internal_tensor_fixture(operator = "SequenceConstruct",
    two_inputs = TRUE, output_sequence = TRUE)
  expect_error(onnx_run(sequence, list(x = matrix(1, 2, 2), y = matrix(2, 2, 2))),
    "non-tensor ONNX output")
  expect_error(onnx_predict(onnx_internal_tensor_fixture(), matrix(1, 2, 2)), "onnx_run")
})

test_that("generic inspection leaves task and tree counts unknown", {
  info <- onnx_inspect(onnx_internal_tensor_fixture())
  expect_identical(info$model$task, "unknown")
  expect_true(is.na(info$model$trees))
  expect_identical(info$engine$version, "1.31.1")
  expect_identical(info$engine$api_version, 31L)
  expect_identical(info$inputs$shape[[1L]], c(NA_real_, 2))
})

test_that("empty tensor batches preserve their declared dimensions", {
  model <- onnx_internal_tensor_fixture()
  expect_identical(dim(onnx_run(model, list(x = matrix(numeric(), 0, 2)))$result), c(0L, 2L))
})
