test_that("all six objectives match XGBoost with missing values and non-default intercepts", {
  objectives <- c("binary:logistic", "binary:logitraw", "reg:squarederror",
    "reg:logistic", "multi:softprob", "multi:softmax")
  for (objective in objectives) {
    fixture <- train_fixture(objective)
    converted <- onnx_convert(fixture$model)
    native <- onnx_predict(converted, fixture$x, "raw")
    reference <- predict(fixture$model, fixture$data)
    if (objective == "binary:logistic") native <- native[, 2L]
    if (objective == "multi:softmax") {
      native <- max.col(native, ties.method = "first") - 1L
    }
    expect_equal(as.numeric(native), as.numeric(reference), tolerance = 3e-6,
      info = objective)
    if (startsWith(objective, "multi:")) {
      expect_equal(rowSums(onnx_predict(converted, fixture$x, "raw")),
        rep(1, nrow(fixture$x)), tolerance = 3e-7)
      expect_error(onnx_predict(converted, fixture$x, "numeric"), "multiclass")
    }
  }
})

test_that("binary base scores and parallel trees retain probabilities", {
  for (base in c(0.15, 0.5, 0.85)) {
    fixture <- train_fixture(base = base, parallel_trees = 3L)
    result <- onnx_predict(onnx_convert(fixture$model), fixture$x, "numeric")$.pred
    expect_equal(result, as.numeric(predict(fixture$model, fixture$data)), tolerance = 3e-6)
  }
})

test_that("feature order and human-readable class labels survive round trips", {
  fixture <- train_fixture()
  model <- onnx_convert(fixture$model,
    params = list(class_levels = c("absence", "presence")))
  frame <- as.data.frame(fixture$x[, 4:1])
  expect_equal(onnx_predict(model, frame), onnx_predict(model, fixture$x))
  expect_equal(onnx_predict(model, fixture$x[, 4:1]), onnx_predict(model, fixture$x))
  expect_named(onnx_predict(model, fixture$x), c(".pred_absence", ".pred_presence"))
  renamed <- onnx_convert(fixture$model, feature_names = paste0("x", 1:4))
  colnames(frame) <- rev(paste0("x", 1:4))
  expect_equal(unname(as.matrix(onnx_predict(renamed, frame))),
    unname(as.matrix(onnx_predict(model, fixture$x))))
  expect_error(onnx_convert(fixture$model, feature_names = "wrong"), "feature_names")
})

test_that("automatically estimated scalar or vector base scores are supported", {
  skip_if_not_installed("xgboost")
  set.seed(19)
  x <- matrix(rnorm(400), ncol = 4)
  d <- xgboost::xgb.DMatrix(x, label = rep(c(0, 1, 2, 0, 0), 20))
  model <- xgboost::xgb.train(list(objective = "multi:softprob", num_class = 3L,
    max_depth = 2L, nthread = 1L), d, nrounds = 6L, verbose = 0L)
  expect_equal(as.numeric(onnx_predict(onnx_convert(model), x, "raw")),
    as.numeric(predict(model, d)), tolerance = 3e-6)
})

test_that("all-positive binary trees have valid portable logistic scores", {
  skip_if_not_installed("xgboost")
  x <- matrix(seq_len(60), ncol = 1)
  d <- xgboost::xgb.DMatrix(x, label = rep(1, 60))
  model <- xgboost::xgb.train(list(objective = "binary:logistic", base_score = 0.2,
    nthread = 1L, max_depth = 1L), d, nrounds = 3L, verbose = 0L)
  converted <- onnx_convert(model)
  expect_equal(onnx_predict(converted, x, "numeric")$.pred,
    as.numeric(predict(model, d)), tolerance = 3e-6)
})


test_that("two-class softmax preserves probabilities after symmetric score conversion", {
  skip_if_not_installed("xgboost")
  set.seed(73)
  x <- matrix(rnorm(500), ncol = 5)
  d <- xgboost::xgb.DMatrix(x, label = as.numeric(rowSums(x) > 0))
  for (objective in c("multi:softprob", "multi:softmax")) {
    model <- xgboost::xgb.train(list(objective = objective, num_class = 2L,
      max_depth = 3L, nthread = 1L, base_score = 0.3), d, nrounds = 8L, verbose = 0L)
    converted <- onnx_convert(model)
    raw <- onnx_predict(converted, x, "raw")
    margins <- predict(model, d, outputmargin = TRUE)
    scores <- exp(margins - apply(margins, 1L, max))
    expect_equal(as.numeric(raw), as.numeric(scores / rowSums(scores)), tolerance = 3e-6)
    expect_equal(converted@task_type, "classification_multiclass")
  }
})

test_that("UTF-8 feature metadata survives conversion under the C locale", {
  skip_if_not_installed("xgboost")
  previous_locale <- Sys.getlocale("LC_CTYPE")
  on.exit(Sys.setlocale("LC_CTYPE", previous_locale), add = TRUE)
  Sys.setlocale("LC_CTYPE", "C")
  set.seed(100)
  x <- matrix(rnorm(200), ncol = 2)
  features <- c("chuva_\u00e1", "temperatura_\u00e7")
  colnames(x) <- features
  data <- xgboost::xgb.DMatrix(x, label = as.numeric(rowSums(x) > 0))
  fit <- xgboost::xgb.train(list(objective = "binary:logistic", nthread = 1L,
    base_score = 0.3, max_depth = 2L), data, nrounds = 4L, verbose = 0L)
  labels <- c("aus\u00eancia", "presen\u00e7a")
  converted <- onnx_convert(fit, params = list(class_levels = labels))
  expect_identical(converted@feature_names, features)
  expect_identical(converted@class_levels, labels)
  prediction <- onnx_predict(converted, as.data.frame(x))
  expect_identical(names(prediction), paste0(".pred_", labels))
  expect_equal(prediction[[2L]], as.numeric(predict(fit, data)), tolerance = 3e-6)
})
