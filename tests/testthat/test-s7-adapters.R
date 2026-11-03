# Exercise public dispatch, soft failures, and independence from optional adapters.
test_that("every public operation uses S7 and private functions use the approved prefix", {
  namespace <- asNamespace("tidyonnx")
  public <- getNamespaceExports("tidyonnx")
  expect_setequal(public, c("onnx_convert", "onnx_save", "onnx_load", "onnx_predict", "onnx_inspect"))
  expect_true(all(vapply(mget(public, namespace), inherits, logical(1), "S7_generic")))
  functions <- Filter(is.function, as.list(namespace, all.names = TRUE))
  private <- setdiff(names(functions), c(public, ".onLoad"))
  expect_true(all(startsWith(private, "onnx_internal_")))
  expect_message(result <- withVisible(onnx_convert(list())), "not recognized")
  expect_null(result$value)
  expect_false(result$visible)
  expect_message(expect_null(onnx_convert(onnx_internal_fixture_model())), "Implemented")
})

# The fixture combines scaling and dummy encoding to catch dropped preprocessing.
onnx_internal_workflow_fixture <- function(event_level = "first", multiclass = FALSE) {
  skip_if_not_installed("workflows")
  skip_if_not_installed("parsnip")
  skip_if_not_installed("recipes")
  skip_if_not_installed("xgboost")
  data <- if (multiclass) iris else iris[1:100, ]
  data$Species <- droplevels(data$Species)
  data$batch <- factor(rep(c("early", "late"), length.out = nrow(data)))
  recipe <- recipes::recipe(Species ~ ., data = data)
  recipe <- recipes::step_normalize(recipe, recipes::all_numeric_predictors())
  recipe <- recipes::step_dummy(recipe, recipes::all_nominal_predictors())
  specification <- parsnip::boost_tree(trees = 5L, tree_depth = 2L, learn_rate = 0.2)
  specification <- parsnip::set_mode(specification, "classification")
  # Inject a literal: parsnip's prediction postprocessor inspects the stored expression.
  specification <- rlang::inject(parsnip::set_engine(specification, "xgboost", nthread = 1L,
    event_level = !!event_level))
  workflow <- workflows::add_recipe(workflows::workflow(), recipe)
  workflow <- workflows::add_model(workflow, specification)
  list(fit = parsnip::fit(workflow, data), data = data)
}

test_that("fitted workflows preserve recipes, event encoding, and RDS restoration", {
  invisible(lapply(c("first", "second"), function(event_level) {
    fixture <- onnx_internal_workflow_fixture(event_level)
    converted <- onnx_convert(fixture$fit)
    expected <- predict(fixture$fit, fixture$data, type = "prob")
    expect_equal(onnx_predict(converted, fixture$data), expected, tolerance = 3e-6)
    expect_equal(predict(converted, fixture$data, type = "class"),
      predict(fixture$fit, fixture$data, type = "class"))
    file <- tempfile(fileext = ".rds")
    on.exit(unlink(file), add = TRUE)
    saveRDS(converted, file)
    expect_equal(onnx_predict(readRDS(file), fixture$data), expected, tolerance = 3e-6)
    destination <- tempfile(fileext = ".onnx")
    expect_error(onnx_save(converted, destination), "preprocessing")
    expect_false(file.exists(destination))
    expect_error(onnx_convert(fixture$fit, feature_names = "renamed"), "schema")
    parsnip <- workflows::extract_fit_parsnip(fixture$fit)
    predictors <- hardhat::forge(fixture$data, workflows::extract_mold(fixture$fit)$blueprint)$predictors
    expect_equal(onnx_predict(onnx_convert(parsnip), predictors), expected, tolerance = 3e-6)
    onnx_save(onnx_convert(parsnip), destination)
    on.exit(unlink(destination), add = TRUE)
    expect_equal(onnx_predict(onnx_load(destination), predictors), expected, tolerance = 3e-6)
  }))
})

test_that("multiclass workflows preserve labels and unfitted workflows end without errors", {
  fixture <- onnx_internal_workflow_fixture(multiclass = TRUE)
  expect_equal(onnx_predict(onnx_convert(fixture$fit), fixture$data),
    predict(fixture$fit, fixture$data, type = "prob"), tolerance = 3e-6)
  expect_message(expect_null(onnx_convert(workflows::workflow())), "fit\\(\\)")
})

# Recognition failures must never create a partial output or conceal an invalid call.
test_that("unsupported booster configurations end with the implemented-format message", {
  skip_if_not_installed("xgboost")
  x <- matrix(seq_len(80) / 80, ncol = 2)
  training <- xgboost::xgb.DMatrix(x, label = rep(c(0, 1), 20), nthread = 1L)
  linear <- xgboost::xgb.train(list(booster = "gblinear", objective = "binary:logistic",
    nthread = 1L), training, nrounds = 2L, verbose = 0L)
  expect_message(expect_null(onnx_convert(linear)), "Implemented")
  stopped <- xgboost::xgb.train(list(objective = "binary:logistic", nthread = 1L),
    training, nrounds = 5L, evals = list(training = training),
    early_stopping_rounds = 2L, verbose = 0L)
  expect_message(expect_null(onnx_convert(stopped)), "Early-stopped")
  expect_error(onnx_convert(list(), params = list(unknown = TRUE)), "Unknown params")
})

test_that("regression workflows return an informative unsupported result", {
  skip_if_not_installed("workflows")
  skip_if_not_installed("parsnip")
  skip_if_not_installed("xgboost")
  specification <- parsnip::boost_tree(trees = 4L, tree_depth = 2L)
  specification <- parsnip::set_mode(specification, "regression")
  specification <- parsnip::set_engine(specification, "xgboost", nthread = 1L)
  workflow <- workflows::add_formula(workflows::workflow(), mpg ~ wt + hp)
  workflow <- workflows::add_model(workflow, specification)
  fit <- parsnip::fit(workflow, mtcars)
  expect_message(expect_null(onnx_convert(fit)), "regression conversion is not implemented")
})
