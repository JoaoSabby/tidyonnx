# Exercise fitted source models against persisted reference predictions across compiler builds.
arguments <- commandArgs(trailingOnly = TRUE)
output_directory <- arguments[[1L]]
configuration <- if (length(arguments) > 1L) arguments[[2L]] else "gcc"
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)

# Generate one reproducible dataset per scenario without altering its original row order.
onnx_internal_matrix_data <- function(seed, task, family, route) {
  set.seed(seed)
  x <- matrix(rnorm(1400L * 6L), ncol = 6L,
    dimnames = list(NULL, paste0("feature_", seq_len(6L))))
  new_x <- matrix(rnorm(600L * 6L), ncol = 6L, dimnames = list(NULL, colnames(x)))
  signal <- 1.2 * x[, 1L] - x[, 2L] + sin(x[, 3L]) + x[, 4L] * x[, 5L]
  y <- if (task == "binary") factor(ifelse(signal > 0, "presence", "absence"),
    levels = c("absence", "presence")) else signal + rnorm(nrow(x), sd = 0.2)
  x[sample.int(length(x), 200L)] <- NA_real_
  new_x[sample.int(length(new_x), 80L)] <- NA_real_
  if (family == "elastic_net" && route != "workflow_recipe") {
    x[is.na(x)] <- 0
    new_x[is.na(new_x)] <- 0
  }
  x <- as.data.frame(x)
  new_x <- as.data.frame(new_x)
  if (route == "workflow_recipe") {
    x$batch <- factor(rep(c("early", "late"), length.out = nrow(x)))
    new_x$batch <- factor(rep(c("early", "late"), length.out = nrow(new_x)))
  }
  list(x = x, y = y, new_x = new_x)
}

# Fit direct engines, parsnip models, or full workflows using the same explicit seed.
onnx_internal_matrix_fit <- function(data, task, family, route, seed) {
  if (route == "direct") {
    if (family == "elastic_net") {
      return(glmnet::glmnet(as.matrix(data$x), data$y, alpha = 0.5, lambda = 0.02,
        family = if (task == "binary") "binomial" else "gaussian"))
    }
    labels <- if (task == "binary") as.integer(data$y == "presence") else data$y
    training <- xgboost::xgb.DMatrix(as.matrix(data$x), label = labels, nthread = 1L)
    return(xgboost::xgb.train(list(objective = if (task == "binary") "binary:logistic" else
      "reg:squarederror", max_depth = 3L, eta = 0.2, nthread = 1L,
      base_score = if (task == "binary") 0.3 else 2, seed = seed),
      training, nrounds = 25L, verbose = 0L))
  }
  if (family == "elastic_net") {
    specification <- if (task == "binary") parsnip::logistic_reg(penalty = 0.02,
      mixture = 0.5) else parsnip::linear_reg(penalty = 0.02, mixture = 0.5)
    specification <- parsnip::set_engine(specification, "glmnet")
  } else {
    specification <- parsnip::boost_tree(trees = 25L, tree_depth = 3L, learn_rate = 0.2)
    specification <- parsnip::set_mode(specification,
      if (task == "binary") "classification" else "regression")
    specification <- parsnip::set_engine(specification, "xgboost", nthread = 1L,
      base_score = if (task == "binary") 0.3 else 2)
  }
  if (route == "parsnip") return(parsnip::fit_xy(specification, x = data$x, y = data$y))
  frame <- data$x
  frame$target <- data$y
  workflow <- workflows::add_model(workflows::workflow(), specification)
  if (route == "workflow_recipe") {
    recipe <- recipes::recipe(target ~ ., data = frame)
    recipe <- recipes::step_impute_median(recipe, recipes::all_numeric_predictors())
    recipe <- recipes::step_normalize(recipe, recipes::all_numeric_predictors())
    recipe <- recipes::step_dummy(recipe, recipes::all_nominal_predictors())
    workflow <- workflows::add_recipe(workflow, recipe)
  } else workflow <- workflows::add_formula(workflow, target ~ .)
  parsnip::fit(workflow, data = frame)
}

# Normalize only the output container; never round or modify the prediction values.
onnx_internal_matrix_reference <- function(model, data, task, family, route) {
  if (route == "direct") {
    probability <- if (family == "xgboost") as.numeric(predict(model,
      xgboost::xgb.DMatrix(as.matrix(data), nthread = 1L))) else
      as.numeric(predict(model, newx = as.matrix(data), s = 0.02, type = "response"))
    if (task == "regression") return(probability)
    result <- cbind(1 - probability, probability)
    colnames(result) <- c(".pred_absence", ".pred_presence")
    return(result)
  }
  result <- predict(model, data, type = if (task == "binary") "prob" else "numeric")
  if (task == "binary") as.matrix(result) else as.numeric(result$.pred)
}

# Record every scenario independently so a failure cannot conceal the other results.
onnx_internal_matrix_case <- function(seed, task, family, route) {
  id <- paste(family, task, route, seed, sep = "-")
  directory <- file.path(output_directory, id)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  tryCatch({
    data <- onnx_internal_matrix_data(seed, task, family, route)
    model <- onnx_internal_matrix_fit(data, task, family, route, seed)
    reference <- onnx_internal_matrix_reference(model, data$new_x, task, family, route)
    reference_file <- file.path(directory, "source-predictions.rds")
    if (file.exists(reference_file)) {
      stopifnot(identical(reference, readRDS(reference_file)))
    } else {
      # This write must happen before attempting ONNX conversion.
      saveRDS(reference, reference_file)
      saveRDS(data, file.path(directory, "data.rds"))
      saveRDS(model, file.path(directory, "source-model.rds"))
      if (family == "xgboost") {
        engine <- if (route == "direct") model else if (route == "parsnip") model$fit else
          workflows::extract_fit_engine(model)
        xgboost::xgb.save(engine, file.path(directory, "source-model.ubj"))
      }
      write.csv(as.data.frame(reference), file.path(directory, "source-predictions.csv"),
        row.names = FALSE)
    }
    messages <- character()
    converted <- withCallingHandlers(tidyonnx::onnx_convert(model,
      params = if (task == "binary" && route == "direct")
        list(class_levels = c("absence", "presence")) else list()),
      message = function(condition) {
        messages <<- c(messages, conditionMessage(condition))
        invokeRestart("muffleMessage")
      })
    writeLines(messages, file.path(directory, paste0(configuration, "-conversion-messages.txt")))
    if (family == "elastic_net" || task == "regression") {
      stopifnot(is.null(converted), any(grepl("not recognized", messages)),
        any(grepl("Implemented", messages)))
      return(data.frame(case = id, configuration = configuration,
        status = "unsupported_expected", exact = NA, max_difference = NA_real_, error = ""))
    }
    stopifnot(!is.null(converted))
    predictions <- lapply(c(1L, 121L, 600L), function(rows) {
      batch <- data$new_x[seq_len(rows), , drop = FALSE]
      expected <- if (task == "binary") reference[seq_len(rows), , drop = FALSE] else
        reference[seq_len(rows)]
      outputs <- lapply(c(1L, 2L), function(threads) {
        result <- tidyonnx::onnx_predict(converted, batch,
          type = if (task == "binary") "prob" else "numeric",
          params = list(intra_op_threads = threads))
        actual <- if (task == "binary") as.matrix(result) else as.numeric(result$.pred)
        if (task == "binary") stopifnot(identical(colnames(actual), colnames(expected)))
        list(rows = rows, threads = threads, actual = actual,
          exact = identical(as.numeric(actual), as.numeric(expected)),
          max_difference = max(abs(actual - expected)))
      })
      stopifnot(identical(outputs[[1L]]$actual, outputs[[2L]]$actual))
      outputs
    })
    results <- unlist(predictions, recursive = FALSE)
    full <- results[[length(results)]]$actual
    saveRDS(full, file.path(directory, paste0(configuration, "-onnx-predictions.rds")))
    write.csv(as.data.frame(full), file.path(directory,
      paste0(configuration, "-onnx-predictions.csv")), row.names = FALSE)
    rds <- file.path(directory, paste0(configuration, "-converted-model.rds"))
    saveRDS(converted, rds)
    restored <- tidyonnx::onnx_predict(readRDS(rds), data$new_x,
      type = if (task == "binary") "prob" else "numeric")
    restored <- if (task == "binary") as.matrix(restored) else as.numeric(restored$.pred)
    stopifnot(identical(restored, full))
    exact <- all(vapply(results, "[[", logical(1), "exact"))
    difference <- max(vapply(results, "[[", numeric(1), "max_difference"))
    data.frame(case = id, configuration = configuration,
      status = if (exact) "pass" else "prediction_mismatch", exact = exact,
      max_difference = difference, error = "")
  }, error = function(condition) data.frame(case = id, configuration = configuration,
    status = "error", exact = FALSE, max_difference = NA_real_, error = conditionMessage(condition)))
}

# Run direct use, parsnip, formula workflows, and recipes for both model families.
grid <- expand.grid(seed = c(428L, 821L, 20261102L), task = c("binary", "regression"),
  family = c("xgboost", "elastic_net"),
  route = c("direct", "parsnip", "workflow_formula", "workflow_recipe"),
  stringsAsFactors = FALSE)
if (identical(Sys.getenv("MATRIX_XGBOOST_ONLY"), "true")) grid <- grid[grid$family == "xgboost", ]
results <- lapply(seq_len(nrow(grid)), function(index) {
  scenario <- grid[index, ]
  result <- onnx_internal_matrix_case(scenario$seed, scenario$task, scenario$family, scenario$route)
  print(result, row.names = FALSE)
  result
})
results <- do.call(rbind, results)
write.csv(results, file.path(output_directory, paste0(configuration, "-matrix-summary.csv")),
  row.names = FALSE)
jsonlite::write_json(results, file.path(output_directory,
  paste0(configuration, "-matrix-summary.json")), pretty = TRUE, digits = 17L, na = "null")
writeLines(c(capture.output(sessionInfo()), paste("source revision:",
  Sys.getenv("SOURCE_REVISION", unset = "local"))), file.path(output_directory,
  paste0(configuration, "-session.txt")))
stopifnot(all(results$status %in% c("pass", "unsupported_expected")))
