#' @title Align numerical input columns with an ensemble schema
#' @description
#' Existing R storage is retained while named columns are aligned to engine order.
#' @details
#' Plain integer and double vectors are accepted. Factors, dates, list columns,
#' and other classed vector types are rejected. Extra data-frame columns are
#' ignored; named and unnamed matrices must have the exact engine width.
#' @param new_data A numerical matrix, data frame, or tibble.
#' @param feature_names Unique predictor names in engine order.
#' @return A list with data buffers, one-based column indices, and row count.
#' @seealso [onnx_predict()]
#' @references <https://stat.ethz.ch/R-manual/R-devel/library/base/html/list.html>
#' @examples
#' PrepareColumns <- getFromNamespace("prepare_input_columns", "tidyonnx")
#' PrepareColumns(data.frame(value = c(1, NA_real_)), "value")
#' @keywords internal
prepare_input_columns <- function(new_data, feature_names){
  if(is.matrix(new_data)){
    if(!typeof(new_data) %in% c("double", "integer") ||
       !identical(class(new_data), c("matrix", "array"))){
      stop("new_data must contain numeric or integer values.", call. = FALSE)
    }
    if(ncol(new_data) != length(feature_names)){
      stop("The matrix column count does not match the model.", call. = FALSE)
    }
    indices <- seq_along(feature_names)
    if(!is.null(colnames(new_data))){
      if(anyNA(colnames(new_data)) || any(!nzchar(colnames(new_data))) ||
          anyDuplicated(colnames(new_data)) ||
          !all(feature_names %in% colnames(new_data))){
        stop("The matrix column names do not match the model.", call. = FALSE)
      }
      indices <- match(feature_names, colnames(new_data))
    }
    return(list(data = new_data, indices = as.integer(indices), rows = nrow(new_data)))
  }
  if(!is.data.frame(new_data) || anyDuplicated(names(new_data)) ||
      !all(feature_names %in% names(new_data))){
    stop("new_data must be a numeric matrix or a data frame with all model features.",
      call. = FALSE)
  }
  columns <- as.list(new_data)[feature_names]
  valid <- vapply(columns, function(column){
    typeof(column) %in% c("double", "integer") && !is.object(column) && is.null(dim(column))
  }, logical(1))
  if(!all(valid)){
    stop("Predictors must be plain numeric or integer columns. Invalid: ",
      paste(feature_names[!valid], collapse = ", "), call. = FALSE)
  }
  list(data = columns, indices = seq_along(feature_names), rows = nrow(new_data))
}
