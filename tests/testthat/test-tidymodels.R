test_that("parsnip event levels, formulas, and probability order survive conversion", {
  skip_if_not_installed("parsnip")
  skip_if_not_installed("xgboost")
  library(parsnip)
  trainData <- data.frame(
    amount = seq_len(80),
    group = factor(rep(c("a", "b"), 40)),
    target = factor(rep(c("yes", "no", "no", "yes"), 20), levels = c("yes", "no"))
  )
  for(eventLevel in c("first", "second")){
    modelSpec <- boost_tree(trees = 6, tree_depth = 2, min_n = 2) |>
      set_engine("xgboost", nthread = 1, event_level = eventLevel) |>
      set_mode("classification")
    fittedModel <- fit(modelSpec, target ~ log(amount) + group, data = trainData)
    convertedModel <- onnx_convert(fittedModel)
    expect_s3_class(convertedModel, "onnx_fit")
    expect_null(convertedModel$template$fit)
    expect_equal(predict(convertedModel, trainData, type = "prob"),
                 predict(fittedModel, trainData, type = "prob"), tolerance = 3e-6)
    expect_equal(predict(convertedModel, trainData), predict(fittedModel, trainData))
    expect_equal(predict(convertedModel, trainData, type = "raw"),
                 predict(fittedModel, trainData, type = "raw"), tolerance = 3e-6)
    expect_equal(onnx_predict(convertedModel, trainData, "prob"),
                 predict(convertedModel, trainData, "prob"))
    expect_error(predict(convertedModel, trainData, type = "numeric"), "classification")
    expect_error(onnx_save(convertedModel, tempfile()), "saveRDS")
    expect_identical(onnx_convert(convertedModel), convertedModel)
    expect_named(onnx_inspect(convertedModel), c("model", "inputs", "outputs", "features", "engine"))
  }
})

test_that("recipe workflows retain imputation, dummy encoding, and serialized prediction", {
  skip_if_not_installed("workflows")
  skip_if_not_installed("recipes")
  skip_if_not_installed("modeldata")
  skip_if_not_installed("xgboost")
  library(workflows)
  library(recipes)
  library(parsnip)
  data("penguins", package = "modeldata")
  trainData <- penguins[c("species", "bill_length_mm", "bill_depth_mm", "island")]
  recipeSpec <- recipe(species ~ ., data = trainData) |>
    step_impute_median(all_numeric_predictors()) |>
    step_dummy(all_nominal_predictors())
  modelSpec <- boost_tree(trees = 6, tree_depth = 2, min_n = 2) |>
    set_engine("xgboost", nthread = 1) |>
    set_mode("classification")
  fittedWorkflow <- workflow() |>
    add_recipe(recipeSpec) |>
    add_model(modelSpec) |>
    fit(data = trainData)
  convertedModel <- onnx_convert(fittedWorkflow)
  expectedProb <- predict(fittedWorkflow, trainData, type = "prob")
  expect_equal(predict(convertedModel, trainData, type = "prob"), expectedProb,
               tolerance = 3e-6)
  expect_equal(predict(convertedModel, trainData), predict(fittedWorkflow, trainData))
  savedModel <- tempfile(fileext = ".rds")
  on.exit(unlink(savedModel), add = TRUE)
  saveRDS(convertedModel, savedModel)
  expect_equal(predict(readRDS(savedModel), trainData, type = "prob"), expectedProb,
               tolerance = 3e-6)
  expect_error(onnx_convert(workflow()), "trained|fit|fitted")
  if(requireNamespace("butcher", quietly = TRUE)){
    Butcher <- getExportedValue("butcher", "butcher")
    reducedModel <- fittedWorkflow |> Butcher() |> onnx_convert()
    expect_equal(predict(reducedModel, trainData, type = "prob"), expectedProb,
                 tolerance = 3e-6)
  }
})

test_that("parsnip regression works through fit_xy and formula workflows", {
  skip_if_not_installed("parsnip")
  skip_if_not_installed("workflows")
  skip_if_not_installed("xgboost")
  library(parsnip)
  library(workflows)
  trainData <- data.frame(x = seq_len(60), y = log(seq_len(60)))
  modelSpec <- boost_tree(trees = 6, tree_depth = 2) |>
    set_engine("xgboost", nthread = 1) |>
    set_mode("regression")
  fittedModel <- fit_xy(modelSpec, x = trainData["x"], y = trainData$y)
  expect_equal(predict(onnx_convert(fittedModel), trainData),
               predict(fittedModel, trainData), tolerance = 3e-6)
  fittedWorkflow <- workflow() |>
    add_formula(y ~ log(x)) |>
    add_model(modelSpec) |>
    fit(data = trainData)
  expect_equal(predict(onnx_convert(fittedWorkflow), trainData),
               predict(fittedWorkflow, trainData), tolerance = 3e-6)
  unsupportedModel <- linear_reg() |> set_engine("lm") |> fit(y ~ x, data = trainData)
  expect_error(onnx_convert(unsupportedModel), "xgboost")
})
