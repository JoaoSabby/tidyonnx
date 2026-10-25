# Predictable return types preserve row order and the original target-level order.
onnx_predict <- function(object, new_data, type = NULL, params = list()) {
  params <- validate_onnx_params(params)
  if (is.character(object) && length(object) == 1L) object <- onnx_load(object, params)
  if (!S7::S7_inherits(object, onnx_model)) {
    stop("object must be an onnx_model or an ONNX file path.", call. = FALSE)
  }
  object <- ensure_active_session(object)
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
  input <- prepare_input_columns(new_data, object@feature_names)
  threads <- params$intra_op_threads
  if (!threads) {
    cores <- parallel::detectCores(logical = FALSE)
    threads <- if (is.na(cores)) 1L else max(1L, as.integer(cores))
  }
  output <- cpp_predict_model(object@session_ptr, input$data, input$indices,
    as.integer(input$rows), as.integer(threads))
  if (type == "raw") return(output)
  if (type == "numeric") {
    return(tibble::tibble(.pred = if (classification) output[, 2L] else output))
  }
  if (type == "class") {
    # A probability exactly equal to 0.5 selects the positive class for binary models.
    index <- if (ncol(output) == 2L) 1L + as.integer(output[, 2L] >= 0.5) else
      max.col(output, ties.method = "first")
    return(tibble::tibble(.pred_class = factor(object@class_levels[index],
      levels = object@class_levels)))
  }
  result <- as.data.frame(output)
  names(result) <- paste0(".pred_", object@class_levels)
  tibble::as_tibble(result, .name_repair = "minimal")
}
