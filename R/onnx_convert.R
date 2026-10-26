#' @title Convert a fitted model to native ONNX prediction
#' @description
#' A supported fitted ensemble is replaced with an ONNX representation. Fitted
#' parsnip objects and workflows retain the preprocessing required by prediction.
#' @details
#' Conversion is a post-fit operation, used after tuning and final fitting in the
#' same pipeline position as model reduction with butcher. Numerical gbtree models
#' support binary:logistic, binary:logitraw, reg:squarederror, reg:logistic,
#' multi:softprob, and multi:softmax. The saved best iteration is honored by
#' default; iteration_range = "all" exports every stored tree. Categorical
#' splits, DART, linear boosters, vector leaves, and custom objectives are outside
#' the conversion contract. Observation-specific base margins are not retained.
#' @param model A fitted xgb.Booster, parsnip model_fit, workflow, converted
#'   onnx_fit, or native tidyonnx model. Failed and untrained fits are rejected.
#' @param feature_names Optional unique character names in engine feature order.
#'   Names default to the stored engine names or f0, f1, and subsequent indices.
#'   Feature names and class labels must not contain line breaks.
#' @param params A uniquely named list of conversion or inference settings.
#'   See [onnx_parameters] for defaults, constraints, and applicable operations.
#' @param ... Reserved for future methods. Additional arguments are rejected.
#' @return A native S7 model for an ensemble, or an onnx_fit prediction bundle
#'   for parsnip and workflow inputs. The bundle contains a native model and the
#'   retained preprocessing contract, without the fitted XGBoost engine.
#' @section Tidymodels integration:
#' Converted bundles accept original predictor data with [predict()]. A workflow
#' applies its trained hardhat blueprint before parsnip encoding. Outcome levels
#' and binary event ordering are preserved. The default prediction type is class
#' for classification bundles and numeric for regression bundles. Native models
#' default to probabilities for classification. Recipes remain R objects and
#' are not included in an exported ONNX graph. Bundles use [saveRDS()] for storage.
#' Workflows with postprocessors are rejected rather than partially converted.
#' @family ONNX model lifecycle
#' @seealso [onnx_predict()], [onnx_save()], [onnx_inspect()]
#' @references
#' * XGBoost model IO:
#'   <https://xgboost.readthedocs.io/en/stable/tutorials/saving_model.html>.
#' * Workflow prediction:
#'   <https://workflows.tidymodels.org/reference/predict-workflow.html>.
#' * Model reduction: <https://butcher.tidymodels.org/reference/butcher.html>.
#' @examplesIf requireNamespace("xgboost") && requireNamespace("modeldata")
#' library(modeldata)
#' library(xgboost)
#' data("penguins", package = "modeldata")
#' trainData <- na.omit(penguins[c("species", "bill_length_mm", "bill_depth_mm")])
#' predictorData <- as.matrix(trainData[c("bill_length_mm", "bill_depth_mm")])
#' trainMatrix <- xgb.DMatrix(predictorData, label = as.integer(trainData$species) - 1L)
#' fittedModel <- xgb.train(
#'   list(objective = "multi:softprob", num_class = 3L, max_depth = 2L, nthread = 1L),
#'   trainMatrix, nrounds = 3L, verbose = 0L
#' )
#' nativeModel <- onnx_convert(
#'   fittedModel, params = list(class_levels = levels(trainData$species))
#' )
#' predict(nativeModel, predictorData[1:3, , drop = FALSE], type = "class")
#' if(requireNamespace("parsnip", quietly = TRUE) &&
#'    requireNamespace("workflows", quietly = TRUE)){
#'   library(parsnip)
#'   library(workflows)
#'   modelSpec <- boost_tree(trees = 3, tree_depth = 2) |>
#'     set_engine("xgboost", nthread = 1) |>
#'     set_mode("classification")
#'   fittedWorkflow <- workflow() |>
#'     add_formula(species ~ bill_length_mm + bill_depth_mm) |>
#'     add_model(modelSpec) |>
#'     fit(data = trainData)
#'   convertedWorkflow <- onnx_convert(fittedWorkflow)
#'   predict(convertedWorkflow, trainData[1:3, ], type = "prob")
#' }
#' @export
onnx_convert <- function(model, feature_names = NULL, params = list(), ...){
  UseMethod("onnx_convert")
}

#' @rdname onnx_convert
#' @export
onnx_convert.default <- function(model, feature_names = NULL, params = list(), ...){
  check_dots_empty()
  validate_onnx_params(params)
  if(S7_inherits(model, onnx_model)){
    if(!is.null(feature_names) && !identical(feature_names, model@feature_names)){
      cli_abort("An ONNX model cannot be renamed during conversion.")
    }
    if(!is.null(params$class_levels) && !identical(params$class_levels, model@class_levels)){
      cli_abort("An ONNX model cannot be relabeled during conversion.")
    }
    return(ensure_active_session(model))
  }
  cli_abort("No serializer is registered for model class {.cls {class(model)}}.")
}

#' @rdname onnx_convert
#' @export
onnx_convert.xgb.Booster <- function(model, feature_names = NULL, params = list(), ...){
  check_dots_empty()
  ConvertBooster(model, feature_names, validate_onnx_params(params))
}

#' @title Serialize a numerical XGBoost engine
#' @description
#' Stable model JSON is decoded once and passed to the native ONNX serializer.
#' @details
#' Class labels are reversed for binary parsnip fits whose event is the first
#' outcome level. This preserves the mapping from encoded target values to labels.
#' Numerical graph validation occurs when the native model is constructed.
#' @param model A fitted xgb.Booster.
#' @param featureNames Optional predictor names in engine order.
#' @param params A fully validated parameter list.
#' @param classLevels Optional outcome levels supplied by a parsnip fit.
#' @param eventFirst Logical; whether binary target value one denotes level one.
#' @return A validated native S7 model containing embedded ONNX bytes.
#' @seealso [onnx_convert()], [model_from_bytes()]
#' @references <https://xgboost.readthedocs.io/en/stable/tutorials/saving_model.html>
#' @keywords internal
ConvertBooster <- function(model, featureNames, params, classLevels = NULL,
                          eventFirst = FALSE){
  CheckOptionalPackage("xgboost")
  SaveRaw <- getExportedValue("xgboost", "xgb.save.raw")
  documentText <- rawToChar(SaveRaw(model, raw_format = "json"))
  Encoding(documentText) <- "UTF-8"
  learner <- fromJSON(documentText, simplifyVector = FALSE)$learner
  bestIteration <- learner$attributes$best_iteration
  if(params$iteration_range == "best" && !is.null(bestIteration)){
    bestIteration <- suppressWarnings(as.numeric(bestIteration))
    if(!IsScalarInteger(bestIteration, 0, .Machine$integer.max - 1)){
      cli_abort("The saved best iteration is invalid.")
    }
    SliceBooster <- getExportedValue("xgboost", "xgb.slice.Booster")
    slicedModel <- SliceBooster(model, start = 1L, end = as.integer(bestIteration) + 1L)
    documentText <- rawToChar(SaveRaw(slicedModel, raw_format = "json"))
    Encoding(documentText) <- "UTF-8"
    learner <- fromJSON(documentText, simplifyVector = FALSE)$learner
  }
  numFeatures <- as.integer(learner$learner_model_param$num_feature)
  storedNames <- unlist(learner$feature_names, use.names = FALSE)
  if(is.null(featureNames)){
    featureNames <- if(length(storedNames)) storedNames else
      str_c("f", seq_len(numFeatures) - 1L)
  }
  if(!is.character(featureNames) || length(featureNames) != numFeatures ||
     anyNA(featureNames) || any(!nzchar(featureNames)) || anyDuplicated(featureNames)){
    cli_abort("{.arg feature_names} must provide one distinct name per model feature.")
  }
  numClasses <- max(2L, as.integer(learner$learner_model_param$num_class))
  if(!is.null(classLevels)){
    if(!is.null(params$class_levels) && !identical(params$class_levels, classLevels)){
      cli_abort("{.arg class_levels} must match the fitted outcome levels.")
    }
    params$class_levels <- if(eventFirst && learner$objective$name == "binary:logistic")
      rev(classLevels) else classLevels
  }
  outputLevels <- params$class_levels
  if(is.null(outputLevels)) outputLevels <- as.character(seq_len(numClasses) - 1L)
  if(length(outputLevels) != numClasses){
    cli_abort("{.arg class_levels} does not match the model's class count.")
  }
  baseScore <- learner$learner_model_param$base_score
  baseScore <- if(startsWith(baseScore, "[")) fromJSON(baseScore) else as.numeric(baseScore)
  bytes <- cpp_serialize_model(
    learner, featureNames, outputLevels, as.double(baseScore),
    params$target_opset, params$ir_version
  )
  model_from_bytes(bytes, "", TRUE)
}
