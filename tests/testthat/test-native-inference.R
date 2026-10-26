test_that("strict split boundaries and missing directions preserve the logistic model", {
  model <- fixture_model()
  data <- matrix(c(0.999999, 1, 1.000001, NA_real_, NaN), ncol = 1)
  expected <- plogis(qlogis(0.3) + c(-0.7, 1.1, 1.1, -0.7, -0.7))
  result <- onnx_predict(model, data)
  expect_s3_class(result, "tbl_df")
  expect_named(result, c(".pred_absent", ".pred_present"))
  expect_equal(result$.pred_present, expected, tolerance = 2e-7)
  expect_equal(rowSums(as.matrix(result)), rep(1, 5), tolerance = 2e-7)
  expect_equal(onnx_predict(model, data, "numeric")$.pred, expected, tolerance = 2e-7)
  expect_equal(levels(onnx_predict(model, data, "class")$.pred_class), c("absent", "present"))
  expect_equal(onnx_predict(model, data, "raw"), as.matrix(result), ignore_attr = TRUE)
  expect_equal(predict(model, data), result)
})

test_that("matrix and data frame storage preserve integer missing values", {
  model <- fixture_model()
  data <- matrix(c(0L, 1L, 2L, NA_integer_), ncol = 1)
  expected <- onnx_predict(model, data)
  expect_equal(onnx_predict(model, data.frame(temperature = data[, 1], extra = letters[1:4])), expected)
  expect_equal(onnx_predict(model, tibble(temperature = data[, 1])), expected)
  expect_equal(onnx_predict(model, matrix(as.double(data), ncol = 1)), expected)
  empty <- data.frame(temperature = integer())
  expect_equal(nrow(onnx_predict(model, empty)), 0L)
  expect_equal(dim(onnx_predict(model, matrix(numeric(), 0, 1), "raw")), c(0L, 2L))
  expect_equal(length(onnx_predict(fixture_model("reg:squarederror"), empty, "raw")), 0L)
})

test_that("regression returns numeric predictions and rejects classification types", {
  model <- fixture_model("reg:squarederror", base = 2)
  expect_equal(onnx_predict(model, matrix(c(0, 2), ncol = 1))$.pred, c(1.3, 3.1),
    tolerance = 2e-7)
  expect_error(onnx_predict(model, matrix(0, 1, 1), "prob"), "Regression")
  expect_error(onnx_predict(model, matrix(0, 1, 1), "class"), "Regression")
})

test_that("thread settings preserve predictions without changing global runtime state", {
  model <- fixture_model()
  x <- matrix(rep(c(0, 1, NA_real_), 900), ncol = 1)
  single <- onnx_predict(model, x, "raw", params = list(intra_op_threads = 1L))
  for (threads in c(2L, 4L)) {
    expect_identical(onnx_predict(model, x, "raw",
      params = list(intra_op_threads = threads)), single)
  }
})
