# Artifact requests use a narrow subclass at the public S3 fit dispatch boundary.
add_onnx <- function(workflow) {
  onnx_internal_require_workflows()
  if (!inherits(workflow, "workflow")) {
    stop("workflow must be a workflows workflow.", call. = FALSE)
  }
  if (workflows::is_trained_workflow(workflow)) {
    stop("add_onnx must be requested before fitting the workflow.", call. = FALSE)
  }
  class(workflow) <- unique(c("tidyonnx_workflow", class(workflow)))
  workflow
}

# Normal workflow fitting runs exactly once before conversion of the fitted engine.
fit.tidyonnx_workflow <- function(object, data, ...) {
  onnx_internal_require_workflows()
  class(object) <- setdiff(class(object), "tidyonnx_workflow")
  fitted <- generics::fit(object, data = data, ...)
  engine <- workflows::extract_fit_engine(fitted)
  mold <- workflows::extract_mold(fitted)
  predictors <- mold$predictors
  outcomes <- mold$outcomes
  if (!is.data.frame(predictors) || !is.data.frame(outcomes) || ncol(outcomes) != 1L ||
      !all(vapply(predictors, is.numeric, logical(1))) ||
      any(vapply(predictors, is.object, logical(1)))) {
    stop("ONNX artifacts require one outcome and prepared plain numeric predictors.",
      call. = FALSE)
  }
  features <- names(predictors)
  if (!inherits(engine, "xgb.Booster")) {
    stop("No serializer is registered for this fitted workflow engine.", call. = FALSE)
  }
  document <- jsonlite::fromJSON(rawToChar(xgboost::xgb.save.raw(engine,
    raw_format = "json")), simplifyVector = FALSE)
  engine_features <- unlist(document$learner$feature_names, use.names = FALSE)
  if (!identical(engine_features, features)) {
    stop("Prepared predictor names or order do not match the fitted XGBoost engine.",
      call. = FALSE)
  }
  outcome <- outcomes[[1L]]
  levels <- if (is.factor(outcome)) levels(outcome) else NULL
  params <- if (is.null(levels)) list() else list(class_levels = levels)
  # Parsnip encodes the first binary factor level as the positive XGBoost class.
  artifact <- onnx_internal_convert_xgboost(engine, features, params,
    target_name = names(outcomes), positive_class = if (length(levels) == 2L) 0L else 1L)
  if (!identical(artifact@feature_names, features) ||
      (!is.null(levels) && !identical(artifact@class_levels, levels))) {
    stop("Workflow outcome levels or prepared predictors disagree with ONNX metadata.",
      call. = FALSE)
  }
  # A parity probe checks score orientation using the public fitted-model accessor.
  rows <- seq_len(min(nrow(predictors), 32L))
  prepared <- predictors[rows, , drop = FALSE]
  engine_fit <- workflows::extract_fit_parsnip(fitted)
  if (length(rows)) {
    reference <- stats::predict(engine_fit, new_data = prepared,
      type = if (is.null(levels)) "numeric" else "prob")
    observed <- onnx_predict(artifact, prepared)
    if (!identical(names(reference), names(observed)) ||
        !isTRUE(all.equal(as.matrix(reference), as.matrix(observed),
          tolerance = 5e-6, check.attributes = FALSE))) {
      stop("Workflow prediction contract disagrees with the exported ONNX artifact.",
        call. = FALSE)
    }
  }
  attr(fitted, "tidyonnx_artifact") <- artifact
  class(fitted) <- c("tidyonnx_workflow", class(fitted))
  fitted
}

# Absence is explicit so an ordinary fitted workflow cannot appear ONNX-enabled.
extract_fit_onnx <- function(fitted_workflow) {
  if (!inherits(fitted_workflow, "workflow")) {
    stop("fitted_workflow must be a fitted workflow.", call. = FALSE)
  }
  artifact <- attr(fitted_workflow, "tidyonnx_artifact", exact = TRUE)
  if (!S7::S7_inherits(artifact, onnx_model)) {
    stop("No ONNX artifact is attached; call add_onnx before a successful direct fit.",
      call. = FALSE)
  }
  onnx_internal_ensure_active_session(artifact)
}

# Optional workflow packages are required only when their integration is requested.
onnx_internal_require_workflows <- function() {
  if (!requireNamespace("workflows", quietly = TRUE)) {
    stop("Install workflows to request an ONNX workflow artifact.", call. = FALSE)
  }
}
