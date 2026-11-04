test_that("replacement failure restores the exact original destination bytes", {
  file <- tempfile(fileext = ".onnx")
  on.exit(unlink(file), add = TRUE)
  original <- as.raw(1:10)
  writeBin(original, file)
  calls <- 0L
  # Fail after moving the original aside, then allow recovery to restore its name.
  rename <- function(from, to) {
    calls <<- calls + 1L
    if (calls == 2L) FALSE else file.rename(from, to)
  }
  expect_error(tidyonnx:::onnx_internal_replace_file(as.raw(11:20), file, rename),
    "original was preserved")
  expect_identical(readBin(file, "raw", 10), original)
  expect_identical(calls, 3L)
})

test_that("backing-file changes with the same schema are detected during restoration", {
  file <- tempfile(fileext = ".onnx")
  rds <- tempfile(fileext = ".rds")
  on.exit(unlink(c(file, rds)), add = TRUE)
  onnx_save(onnx_internal_fixture_model(base = 0.2), file)
  model <- onnx_load(file, list(embed_raw_bytes = FALSE))
  saveRDS(model, rds)
  onnx_save(onnx_internal_fixture_model(base = 0.8), file)
  expect_error(onnx_predict(readRDS(rds), matrix(0, 1, 1)), "backing model file changed")
  expect_error(onnx_save(model, tempfile(fileext = ".onnx")), "backing model file changed")
})

test_that("embedded models preserve exact bytes across copies and garbage collection", {
  model <- onnx_internal_fixture_model()
  file <- tempfile(fileext = ".onnx")
  on.exit(unlink(file), add = TRUE)
  expected <- onnx_predict(model, matrix(c(0, 2, NA_real_), 3, 1))
  copy <- unserialize(serialize(model, NULL))
  for (i in seq_len(10L)) {
    onnx_save(copy, file)
    restored <- onnx_load(file)
    expect_identical(restored@raw_bytes, model@raw_bytes)
    expect_equal(onnx_predict(restored, matrix(c(0, 2, NA_real_), 3, 1)), expected)
    gc()
  }
})

test_that("target metadata never renames graph outputs or invents class labels", {
  fixture <- onnx_internal_train_fixture()
  original <- onnx_convert(fixture$model)
  converted <- onnx_convert(fixture$model, target_name = "outcome")
  expect_identical(converted@target_name, "outcome")
  expect_identical(converted@class_levels, c("0", "1"))
  expect_identical(onnx_inspect(converted)$outputs$name, onnx_inspect(original)$outputs$name)
  file <- tempfile(fileext = ".onnx")
  on.exit(unlink(file), add = TRUE)
  onnx_save(converted, file)
  expect_identical(onnx_load(file)@target_name, "outcome")
  expect_error(onnx_convert(converted, target_name = "other"), "target metadata")
  for (features in list(rep("x", 4), c("x", NA, "z", "w"), "x")) {
    expect_error(onnx_convert(fixture$model, features), "feature_names")
  }
})

test_that("graph labels agree with class decisions away from exact score ties", {
  model <- onnx_internal_fixture_model()
  x <- matrix(c(0, 1, 2, NA_real_), ncol = 1)
  raw <- onnx_run(model, list(features = x))
  classes <- onnx_predict(model, x, "class")$.pred_class
  expect_identical(as.character(classes), model@class_levels[as.numeric(raw$label) + 1L])
})

test_that("legacy embedded artifacts migrate without retaining former session invariants", {
  model <- onnx_internal_fixture_model()
  expected <- onnx_predict(model, matrix(0, 1, 1))
  model@metadata$source_sha256 <- NULL
  model@metadata$session_cache$params <- NULL
  migrated <- tidyonnx:::onnx_internal_ensure_active_session(model)
  expect_equal(onnx_predict(migrated, matrix(0, 1, 1)), expected)
  expect_match(migrated@metadata$source_sha256, "^[a-f0-9]{64}$")
})

test_that("exact binary ties retain the tidy decision independently of the graph label", {
  model <- onnx_internal_fixture_model(base = plogis(0.7))
  input <- matrix(0, 1, 1)
  output <- onnx_run(model, list(features = input))
  expect_identical(output$probabilities[1L, 2L], 0.5)
  expect_identical(as.numeric(output$label), 0)
  expect_identical(as.character(onnx_predict(model, input, "class")$.pred_class), "present")
})
