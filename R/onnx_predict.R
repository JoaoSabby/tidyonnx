#' @title Predict with a native ONNX model or converted fit
#' @description
#' Validated numerical predictors are evaluated by the bundled C tree engine.
#' Converted fits apply their retained R preprocessing before native inference.
#' @details
#' Named columns are aligned with stored feature order. Extra data-frame columns
#' are ignored. An unnamed matrix must already use engine order. Integer and
#' double buffers are borrowed without constructing a row-major input copy.
#' Missing values follow learned tree directions. Infinite values and finite
#' values outside the float32 range are rejected before conversion.
#' @param object A native model, an onnx_fit bundle, or a scalar ONNX file path.
#' @param new_data A numeric or integer matrix, data frame, or tibble. Bundles
#'   accept the original predictor data required by their fitted preprocessing.
#' @param type One of prob, class, numeric, or raw, or NULL. Native classification
#'   defaults to prob; classification bundles default to class. Regression
#'   defaults to numeric. Raw denotes unformatted responses, not output margins.
#' @inheritParams onnx_convert
#' @return A tibble with .pred, .pred_class, or .pred_{level} columns. Raw output
#'   is a numeric regression vector or a classification score matrix. Class
#'   predictions are factors in saved outcome order. Empty batches retain the
#'   same output schema with zero rows. External graph scores follow the graph's
#'   post-transform and are not necessarily normalized probabilities.
#' @section Numerical semantics:
#' Converted binary logistic models select the encoded positive class at a
#' probability of 0.5. Other classifiers select the largest class score, with
#' ties resolved in favor of the first stored class. Floating-point differences
#' at float32 precision are expected relative to independent implementations.
#' @family ONNX model lifecycle
#' @seealso [predict.onnx_fit()], [onnx_inspect()], [onnx_parameters]
#' @references <https://onnx.ai/onnx/operators/onnx_aionnxml_TreeEnsembleClassifier.html>
#' @examplesIf requireNamespace("xgboost") && requireNamespace("modeldata")
#' example("onnx_convert", package = "tidyonnx", ask = FALSE)
#' onnx_predict(nativeModel, predictorData[1:3, , drop = FALSE], type = "prob")
#' @export
onnx_predict <- function(object, new_data, type = NULL, params = list()){
  if(inherits(object, "onnx_fit")){
    return(predict(object, new_data, type = type, params = params))
  }
  params <- validate_onnx_params(params)
  if(is.character(object) && length(object) == 1L) object <- onnx_load(object, params)
  if(!S7_inherits(object, onnx_model)){
    cli_abort("{.arg object} must be an onnx_model, onnx_fit, or an ONNX file path.")
  }
  object <- ensure_active_session(object)
  classification <- object@task_type != "regression"
  if(is.null(type)) type <- if(classification) "prob" else "numeric"
  if(!is.character(type) || length(type) != 1L || is.na(type) ||
     !type %in% c("prob", "class", "numeric", "raw")){
    cli_abort("{.arg type} must be prob, class, numeric, or raw.")
  }
  if(!classification && type %in% c("prob", "class")){
    cli_abort("Regression models do not produce classes or class probabilities.")
  }
  if(object@task_type == "classification_multiclass" && type == "numeric"){
    cli_abort("Use prob, class, or raw for multiclass models.")
  }
  input <- prepare_input_columns(new_data, object@feature_names)
  threads <- InferenceThreads(params$intra_op_threads)
  output <- cpp_predict_model(
    SessionPointer(object), input$data, input$indices, as.integer(input$rows), threads
  )
  if(type == "raw") return(output)
  if(type == "numeric"){
    return(tibble(.pred = if(classification) output[, 2L] else output))
  }
  if(type == "class"){
    thresholdBinary <- isTRUE(object@metadata$binary_threshold)
    index <- if(thresholdBinary) 1L + as.integer(output[, 2L] >= 0.5) else
      max.col(output, ties.method = "first")
    return(tibble(.pred_class = factor(object@class_levels[index],
                                      levels = object@class_levels)))
  }
  colnames(output) <- str_c(".pred_", object@class_levels)
  as_tibble(output, .name_repair = "minimal")
}

#' @title Resolve a bounded inference worker count
#' @description
#' Automatic physical-core detection is cached and bounded to the native limit.
#' @param requested A validated integer worker limit, or zero for detection.
#' @return An integer between one and 1024. Small batches may use fewer workers.
#' @seealso [onnx_parameters]
#' @references
#'   <https://stat.ethz.ch/R-manual/R-devel/library/parallel/html/detectCores.html>
#' @keywords internal
InferenceThreads <- function(requested){
  if(requested > 0L) return(requested)
  if(is.null(.threadCache$cores)){
    cores <- detectCores(logical = FALSE)
    .threadCache$cores <- if(length(cores) != 1L || is.na(cores)) 1L else
      max(1L, min(1024L, as.integer(cores)))
  }
  .threadCache$cores
}

.threadCache <- new.env(parent = emptyenv())
