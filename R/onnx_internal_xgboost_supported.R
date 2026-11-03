# Reject unsupported model semantics before allocating a native conversion session.
onnx_internal_xgboost_supported <- function(learner) {
  objectives <- c("binary:logistic", "binary:logitraw", "reg:squarederror",
    "reg:logistic", "multi:softprob", "multi:softmax")
  booster <- learner$gradient_booster
  trees <- booster$model$trees
  numeric_trees <- length(trees) > 0L && all(vapply(trees, function(tree) {
    all(unlist(tree$split_type, use.names = FALSE) == 0L) &&
      as.integer(tree$tree_param$size_leaf_vector) <= 1L
  }, logical(1)))
  identical(booster$name, "gbtree") && learner$objective$name %in% objectives &&
    as.integer(learner$learner_model_param$num_target) <= 1L && numeric_trees
}
