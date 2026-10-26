#' @title Validate the portable native model contract
#' @description
#' Prediction task, feature schema, persistence source, and outcome labels are
#' checked when an S7 model is created or modified.
#' @param self A candidate native S7 model.
#' @return NULL for a valid contract, otherwise a scalar validation message.
#' @seealso [onnx_model], [model_from_bytes()]
#' @references <https://rconsortium.github.io/S7/articles/classes-objects.html>
#' @keywords internal
ValidateOnnxModel <- function(self){
  validTasks <- c("regression", "classification_binary", "classification_multiclass")
  if(length(self@task_type) != 1L || !self@task_type %in% validTasks){
    return("task_type must identify a supported prediction task.")
  }
  if(!length(self@feature_names) || anyNA(self@feature_names) ||
     any(!nzchar(self@feature_names)) || anyDuplicated(self@feature_names)){
    return("feature_names must be nonempty, unique, non-missing strings.")
  }
  if(length(self@model_path) != 1L || is.na(self@model_path)){
    return("model_path must be one non-missing string.")
  }
  if(!length(self@raw_bytes) && !file.exists(self@model_path)){
    return("A model requires embedded raw bytes or an existing model file.")
  }
  classLevels <- self@class_levels
  if(self@task_type != "regression" &&
     (length(classLevels) < 2L || anyNA(classLevels) ||
      any(!nzchar(classLevels)) || anyDuplicated(classLevels))){
    return("Classification requires at least two distinct nonempty class labels.")
  }
  if(self@task_type == "classification_binary" && length(classLevels) != 2L){
    return("Binary classification requires exactly two class labels.")
  }
  if(self@task_type == "regression" && length(classLevels)){
    return("Regression models cannot contain class labels.")
  }
  NULL
}

#' @title Portable native ensemble model class
#' @description
#' An S7 class owns the native session, portable model bytes, schema, and metadata.
#' @details
#' Instances are constructed by [onnx_convert()] and [onnx_load()]. Native
#' pointers are process-local resources. Embedded bytes or a checksum-verified
#' backing file are the portable source used to rebuild a serialized session.
#' @section Properties:
#' session_ptr stores the native external pointer. model_path records a backing
#' file. raw_bytes contains the portable graph. source_class, task_type,
#' feature_names, and class_levels describe the prediction contract. metadata
#' contains validated engine information and the shared session cache.
#' @return An S7 class constructor, retained internally by the package.
#' @seealso [ValidateOnnxModel()], [onnx_convert()], [onnx_load()]
#' @references <https://rconsortium.github.io/S7/>
#' @keywords internal
onnx_model <- new_class(
  "onnx_model",
  package = "tidyonnx",
  properties = list(
    session_ptr = class_any,
    model_path = new_property(class_character, default = ""),
    raw_bytes = new_property(class_raw, default = raw()),
    source_class = new_property(class_character, default = "unknown"),
    task_type = class_character,
    feature_names = class_character,
    class_levels = new_property(class_character, default = character()),
    metadata = new_property(class_list, default = list())
  ),
  validator = ValidateOnnxModel
)
