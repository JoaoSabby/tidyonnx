# Tidy prediction is available only for explicitly recognized tabular task metadata.
onnx_predict <- function(object, new_data, type = NULL, params = list()) {
  onnx_internal_check_param_context(params, "predict")
  if (is.character(object) && length(object) == 1L) object <- onnx_load(object, params)
  if (!S7::S7_inherits(object, onnx_model)) {
    stop("object must be an onnx_model or an ONNX file path.", call. = FALSE)
  }
  # Empty params retain the session's selected runtime settings instead of resetting them.
  object <- onnx_internal_ensure_active_session(object,
    if (length(params)) onnx_internal_validate_onnx_params(params) else NULL)
  if (object@task_type == "unknown") {
    stop("No recognized tidy prediction contract; use onnx_run with named tensors.",
      call. = FALSE)
  }
  classification <- object@task_type != "regression"
  if (is.null(type)) type <- if (classification) "prob" else "numeric"
  if (!is.character(type) || length(type) != 1L || is.na(type) ||
      !type %in% c("prob", "class", "numeric", "raw")) {
    stop("type must be prob, class, numeric, or raw.", call. = FALSE)
  }
  if (!classification && type %in% c("prob", "class")) {
    stop("Regression models do not produce classes or class probabilities.", call. = FALSE)
  }
  if (object@task_type == "classification_multiclass" && type == "numeric") {
    stop("Use prob, class, or raw for multiclass models.", call. = FALSE)
  }
  prepared <- onnx_internal_prepare_input_columns(new_data, object@feature_names)
  if (is.matrix(prepared$data)) {
    tensor <- prepared$data[, prepared$indices, drop = FALSE]
  } else {
    tensor <- matrix(unlist(prepared$data, use.names = FALSE), nrow = prepared$rows,
      ncol = length(object@feature_names))
  }
  values <- onnx_run(object, list(features = tensor))
  output <- if (classification) values$probabilities else as.numeric(values$prediction)
  expected <- if (classification) c(prepared$rows, length(object@class_levels)) else
    c(prepared$rows, 1L)
  actual <- if (classification) dim(values$probabilities) else dim(values$prediction)
  if (!identical(as.integer(actual), as.integer(expected))) {
    stop("ONNX output shape does not match the tidy tabular contract.", call. = FALSE)
  }
  if (type == "raw") return(output)
  if (type == "numeric") {
    positive <- if (identical(object@metadata$custom$binary_positive_class, "0")) 1L else 2L
    return(tibble::tibble(.pred = if (classification) output[, positive] else output))
  }
  if (type == "class") {
    # The existing binary tie rule selects the positive class at exactly one half.
    positive <- if (identical(object@metadata$custom$binary_positive_class, "0")) 1L else 2L
    index <- if (ncol(output) == 2L) {
      ifelse(output[, positive] >= 0.5, positive, 3L - positive)
    } else max.col(output, ties.method = "first")
    return(tibble::tibble(.pred_class = factor(object@class_levels[index],
      levels = object@class_levels)))
  }
  result <- as.data.frame(output)
  names(result) <- paste0(".pred_", object@class_levels)
  tibble::as_tibble(result, .name_repair = "minimal")
}
