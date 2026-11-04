# Portable sources and generic tensor metadata remain valid after native caches expire.
onnx_model <- S7::new_class(
  "onnx_model", package = "tidyonnx",
  properties = list(
    session_ptr = S7::class_any,
    model_path = S7::new_property(S7::class_character, default = ""),
    raw_bytes = S7::new_property(S7::class_raw, default = raw()),
    source_class = S7::new_property(S7::class_character, default = "external"),
    task_type = S7::new_property(S7::class_character, default = "unknown"),
    target_name = S7::new_property(S7::class_character, default = ""),
    feature_names = S7::new_property(S7::class_character, default = character()),
    class_levels = S7::new_property(S7::class_character, default = character()),
    metadata = S7::new_property(S7::class_list, default = list())
  ),
  # Generic ONNX sessions need no inferred tree, feature or classification contract.
  validator = function(self) {
    tasks <- c("unknown", "regression", "classification_binary", "classification_multiclass")
    if (length(self@task_type) != 1L || !self@task_type %in% tasks) {
      return("task_type must identify a recognized task or unknown.")
    }
    if (length(self@model_path) != 1L || is.na(self@model_path) ||
        length(self@target_name) != 1L || is.na(self@target_name)) {
      return("Model path and target name must be scalar, non-missing strings.")
    }
    if (!length(self@raw_bytes) && !file.exists(self@model_path)) {
      return("A model requires embedded raw bytes or an existing model file.")
    }
    if (anyNA(self@feature_names) || any(!nzchar(self@feature_names)) ||
        anyDuplicated(self@feature_names)) {
      return("Feature names must be unique, nonempty, non-missing strings.")
    }
    if (self@task_type != "unknown" && !length(self@feature_names)) {
      return("A recognized tabular model requires feature names.")
    }
    if (startsWith(self@task_type, "classification") &&
        (length(self@class_levels) < 2L || anyNA(self@class_levels) ||
         any(!nzchar(self@class_levels)) || anyDuplicated(self@class_levels))) {
      return("Classification requires distinct, nonempty class levels.")
    }
    NULL
  }
)
