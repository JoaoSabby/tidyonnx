# Expected unsupported inputs end this call without raising an error condition.
onnx_internal_unrecognized_model <- function(model, reason = NULL) {
  implemented <- paste(
    "Implemented: numerical XGBoost gbtree models with objectives",
    "binary:logistic, binary:logitraw, reg:squarederror, reg:logistic,",
    "multi:softprob, multi:softmax; fitted XGBoost parsnip models and workflows."
  )
  message("Model object was not recognized as a supported source model (class: ",
    paste(class(model), collapse = "/"), ").",
    if (!is.null(reason)) paste0(" ", reason), "\n", implemented)
  invisible(NULL)
}
