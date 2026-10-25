# Preserve R's existing column storage; the native evaluator reads it by stride.
prepare_input_columns <- function(new_data, feature_names) {
  if (is.matrix(new_data)) {
    if (!typeof(new_data) %in% c("double", "integer")) {
      stop("new_data must contain numeric or integer values.", call. = FALSE)
    }
    if (ncol(new_data) != length(feature_names)) {
      stop("The matrix column count does not match the model.", call. = FALSE)
    }
    indices <- seq_along(feature_names)
    if (!is.null(colnames(new_data))) {
      if (anyDuplicated(colnames(new_data)) ||
          !all(feature_names %in% colnames(new_data))) {
        stop("The matrix column names do not match the model.", call. = FALSE)
      }
      indices <- match(feature_names, colnames(new_data))
    }
    return(list(data = new_data, indices = as.integer(indices), rows = nrow(new_data)))
  }
  if (!is.data.frame(new_data) || anyDuplicated(names(new_data)) ||
      !all(feature_names %in% names(new_data))) {
    stop("new_data must be a numeric matrix or a data frame with all model features.",
      call. = FALSE)
  }
  columns <- unclass(new_data[feature_names])
  valid <- vapply(columns, function(column) {
    typeof(column) %in% c("double", "integer") && !is.object(column) && is.null(dim(column))
  }, logical(1))
  if (!all(valid)) {
    stop("Predictors must be plain numeric or integer columns. Invalid: ",
      paste(feature_names[!valid], collapse = ", "), call. = FALSE)
  }
  list(data = columns, indices = seq_along(feature_names), rows = nrow(new_data))
}
