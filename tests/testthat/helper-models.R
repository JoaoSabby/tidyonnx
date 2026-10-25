# Deterministic native fixtures exercise the package even when xgboost is absent.
fixture_model <- function(objective = "binary:logistic", base = 0.3) {
  tree <- list(
    tree_param = list(size_leaf_vector = "1"),
    left_children = list(1L, -1L, -1L),
    right_children = list(2L, -1L, -1L),
    split_indices = list(0L, 0L, 0L),
    split_conditions = list(1, -0.7, 1.1),
    default_left = list(TRUE, FALSE, FALSE),
    split_type = list(0L, 0L, 0L)
  )
  learner <- list(
    objective = list(name = objective),
    learner_model_param = list(num_class = "0", num_target = "1"),
    gradient_booster = list(name = "gbtree", model = list(
      trees = list(tree), tree_info = list(0L)))
  )
  bytes <- tidyonnx:::cpp_serialize_model(
    learner, "temperature", c("absent", "present"), as.double(base), 18L, 8L
  )
  tidyonnx:::model_from_bytes(bytes, "", TRUE)
}

train_fixture <- function(objective = "binary:logistic", base = 0.3,
    rounds = 15L, parallel_trees = 1L) {
  skip_if_not_installed("xgboost")
  set.seed(428)
  x <- matrix(rnorm(360 * 4), ncol = 4)
  colnames(x) <- c("temperature", "rainfall", "altitude", "soil")
  x[sample(length(x), 80)] <- NA_real_
  signal <- rowSums(replace(x, is.na(x), 0))
  multiclass <- startsWith(objective, "multi:")
  y <- if (multiclass) as.numeric(cut(signal, breaks = c(-Inf, -0.5, 0.6, Inf))) - 1 else
    if (objective == "reg:squarederror" || objective == "binary:logitraw") signal else
      as.numeric(signal > 0)
  if (objective == "binary:logitraw") y <- as.numeric(signal > 0)
  parameters <- list(objective = objective, max_depth = 3L, eta = 0.2,
    nthread = 1L, base_score = base, num_parallel_tree = parallel_trees)
  if (multiclass) parameters$num_class <- 3L
  data <- xgboost::xgb.DMatrix(x, label = y, nthread = 1L)
  model <- xgboost::xgb.train(parameters, data, nrounds = rounds, verbose = 0L)
  list(model = model, x = x, data = data)
}
