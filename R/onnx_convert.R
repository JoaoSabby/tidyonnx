# Convert XGBoost model JSON before handing tree validation and encoding to C++.
onnx_convert <- function(model, feature_names = NULL, params = list()){
  params <- validate_onnx_params(params)

  if(S7_inherits(model, onnx_model)){
    if(!is.null(feature_names) && !identical(feature_names, model@feature_names)){
      stop("An ONNX model cannot be renamed during conversion.", call. = FALSE)
    }

    return(ensure_active_session(model))
  }

  if(!inherits(model, "xgb.Booster")){
    stop("No serializer is registered for model class: ",
      paste(class(model), collapse = "/"), ".", call. = FALSE)
  }

  if(!requireNamespace("xgboost", quietly = TRUE)){
    stop("Install xgboost to convert xgb.Booster models.", call. = FALSE)
  }

  # Preserve vector intercepts and UTF-8 names in the serialized XGBoost model
  saveRaw <- getExportedValue("xgboost", "xgb.save.raw")
  documentText <- rawToChar(saveRaw(model, raw_format = "json"))
  Encoding(documentText) <- "UTF-8"
  document <- fromJSON(documentText, simplifyVector = FALSE)
  learner <- document$learner

  # Use stored names when available, with ONNX feature positions as the fallback
  numFeatures <- as.integer(learner$learner_model_param$num_feature)
  storedNames <- unlist(learner$feature_names, use.names = FALSE)

  if(is.null(feature_names)){
    feature_names <- if(length(storedNames)) storedNames else
      str_c("f", seq_len(numFeatures) - 1L)
  }

  if(!is.character(feature_names) || length(feature_names) != numFeatures ||
      anyNA(feature_names) || any(!nzchar(feature_names)) ||
      anyDuplicated(feature_names)){
    stop("feature_names must provide one distinct name per model feature.", call. = FALSE)
  }

  # Only the classifier objectives expose class labels in the graph
  classifier <- learner$objective$name %in% c("binary:logistic", "multi:softprob", "multi:softmax")
  classLevels <- params$class_levels

  if(!classifier && !is.null(classLevels)){
    stop("Regression models do not support class_levels.", call. = FALSE)
  }

  if(classifier){
    numClasses <- max(2L, as.integer(learner$learner_model_param$num_class))

    if(is.null(classLevels)){
      classLevels <- as.character(seq_len(numClasses) - 1L)
    }

    if(length(classLevels) != numClasses){
      stop("class_levels does not match the model's class count.", call. = FALSE)
    }
  } else {
    classLevels <- character()
  }

  # XGBoost can encode the intercept as a number, a JSON array, or numeric text
  baseScore <- learner$learner_model_param$base_score

  if(is.list(baseScore)){
    baseScore <- unlist(baseScore, use.names = FALSE)
  } else if(is.character(baseScore) && length(baseScore) == 1L && startsWith(baseScore, "[")){
    baseScore <- unlist(fromJSON(baseScore), use.names = FALSE)
  }

  bytes <- cpp_serialize_model(learner, feature_names, classLevels,
    as.double(baseScore), params$target_opset, params$ir_version)

  # In-memory objects require embedded bytes to restore the native session
  model_from_bytes(bytes, "", TRUE)
}
