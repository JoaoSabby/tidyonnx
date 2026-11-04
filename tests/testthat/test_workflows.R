test_that("direct workflow fits retain ordinary predictions and attach a complete artifact", {
  skip_if_not_installed("workflows")
  skip_if_not_installed("parsnip")
  skip_if_not_installed("xgboost")
  set.seed(412)
  data <- data.frame(x = rnorm(100), z = rnorm(100))
  data$y <- factor(ifelse(data$x + data$z > 0, "present", "absent"),
    levels = c("present", "absent"))
  spec <- parsnip::boost_tree(trees = 6L, tree_depth = 2L) |>
    parsnip::set_mode("classification") |>
    parsnip::set_engine("xgboost", nthread = 1L)
  workflow <- workflows::workflow(y ~ ., spec)
  set.seed(12)
  ordinary <- generics::fit(workflow, data)
  set.seed(12)
  fitted <- generics::fit(add_onnx(workflow), data)
  artifact <- extract_fit_onnx(fitted)
  expect_true(S7::S7_inherits(artifact, tidyonnx:::onnx_model))
  expect_identical(artifact@target_name, "y")
  expect_identical(artifact@class_levels, levels(data$y))
  expect_identical(artifact@feature_names, c("x", "z"))
  expect_equal(predict(fitted, data, type = "prob"), predict(ordinary, data, type = "prob"))
  expect_equal(onnx_predict(artifact, data), predict(fitted, data, type = "prob"), tolerance = 5e-6)
  expect_equal(onnx_predict(artifact, data, "class"), predict(fitted, data), tolerance = 5e-6)
  expect_error(extract_fit_onnx(ordinary), "No ONNX artifact")
  expect_error(add_onnx(ordinary), "before fitting")
  expect_error(add_onnx(list()), "workflow")
})

test_that("recipe artifacts accept prepared numeric predictors and preserve workflow recipes", {
  skip_if_not_installed("workflows")
  skip_if_not_installed("recipes")
  skip_if_not_installed("parsnip")
  skip_if_not_installed("xgboost")
  data <- data.frame(x = seq_len(80), z = rep(c(1, 3), 40))
  data$y <- data$x / 3 + data$z
  recipe <- recipes::recipe(y ~ ., data) |> recipes::step_normalize(recipes::all_predictors())
  spec <- parsnip::boost_tree(trees = 5L) |> parsnip::set_mode("regression") |>
    parsnip::set_engine("xgboost", nthread = 1L)
  workflow <- workflows::workflow(recipe, spec)
  fitted <- generics::fit(add_onnx(workflow), data)
  artifact <- extract_fit_onnx(fitted)
  prepared <- recipes::bake(workflows::extract_recipe(fitted), new_data = data,
    recipes::all_predictors())
  expect_equal(onnx_predict(artifact, prepared), predict(fitted, data), tolerance = 5e-6)
  expect_identical(names(workflows::extract_mold(fitted)$predictors), artifact@feature_names)
  expect_s3_class(workflows::extract_recipe(fitted), "recipe")
})

test_that("unsupported requested engines fail the direct fit rather than losing artifacts", {
  skip_if_not_installed("workflows")
  skip_if_not_installed("parsnip")
  data <- data.frame(x = 1:10, y = 1:10)
  workflow <- workflows::workflow(y ~ x,
    parsnip::linear_reg() |> parsnip::set_engine("lm"))
  expect_error(generics::fit(add_onnx(workflow), data), "No serializer")
  expect_error(extract_fit_onnx(list()), "fitted workflow")
})

test_that("multiclass workflow class order is retained", {
  skip_if_not_installed("workflows")
  skip_if_not_installed("parsnip")
  skip_if_not_installed("xgboost")
  data <- iris
  levels(data$Species) <- c("zebra", "first", "middle")
  spec <- parsnip::boost_tree(trees = 5L) |> parsnip::set_mode("classification") |>
    parsnip::set_engine("xgboost", nthread = 1L)
  workflow <- workflows::workflow(Species ~ ., spec)
  fitted <- generics::fit(add_onnx(workflow), data)
  artifact <- extract_fit_onnx(fitted)
  expect_identical(artifact@class_levels, levels(data$Species))
  expect_equal(onnx_predict(artifact, data), predict(fitted, data, type = "prob"),
    tolerance = 5e-6)
})
