# The external pointer is owned by cpp11; raw bytes are the portable source of truth.
onnx_model <- S7::new_class(
  "onnx_model",
  package = "tidyonnx",
  properties = list(
    session_ptr = S7::class_any,
    model_path = S7::new_property(S7::class_character, default = ""),
    raw_bytes = S7::new_property(S7::class_raw, default = raw()),
    source_class = S7::new_property(S7::class_character, default = "unknown"),
    task_type = S7::class_character,
    feature_names = S7::class_character,
    class_levels = S7::new_property(S7::class_character, default = character()),
    metadata = S7::new_property(S7::class_list, default = list())
  ),
  validator = function(self) {
    valid_tasks <- c("regression", "classification_binary", "classification_multiclass")
    if (length(self@task_type) != 1L || !self@task_type %in% valid_tasks) {
      return("task_type must identify a supported prediction task.")
    }
    if (!length(self@feature_names) || anyNA(self@feature_names) ||
        any(!nzchar(self@feature_names)) || anyDuplicated(self@feature_names)) {
      return("feature_names must be nonempty, unique, non-missing strings.")
    }
    if (length(self@model_path) != 1L || is.na(self@model_path)) {
      return("model_path must be one non-missing string.")
    }
    if (!length(self@raw_bytes) && !file.exists(self@model_path)) {
      return("A model requires embedded raw bytes or an existing model file.")
    }
    if (self@task_type != "regression" &&
        (length(self@class_levels) < 2L || anyNA(self@class_levels) ||
         anyDuplicated(self@class_levels))) {
      return("Classification requires at least two distinct class labels.")
    }
    NULL
  }
)
