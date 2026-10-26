#' @title Inspect a validated ONNX ensemble and execution engine
#' @description
#' Model metadata, graph input and output schemas, feature order, and available
#' native engine capabilities are returned as a named collection of tibbles.
#' @inheritParams onnx_predict
#' @inheritParams onnx_convert
#' @details
#' A converted classification graph includes one constant intercept tree in
#' addition to its source trees. Workflow inspection describes the numerical
#' ensemble; the retained R preprocessing is available in the prediction bundle.
#' @return A list containing model, inputs, outputs, features, and engine tibbles.
#'   Unknown row dimensions are represented by NA_integer_. Engine OpenMP status
#'   reflects the installed build rather than requested thread settings.
#' @family ONNX model lifecycle
#' @seealso [onnx_convert()], [onnx_load()], [onnx_predict()]
#' @references <https://onnx.ai/onnx/repo-docs/IR.html>
#' @examplesIf requireNamespace("xgboost") && requireNamespace("modeldata")
#' example("onnx_convert", package = "tidyonnx", ask = FALSE)
#' onnx_inspect(nativeModel)
#' @export
onnx_inspect <- function(object, params = list()){
  validate_onnx_params(params)
  if(inherits(object, "onnx_fit")) object <- object$model
  if(is.character(object) && length(object) == 1L) object <- onnx_load(object)
  if(!S7_inherits(object, onnx_model)){
    cli_abort("{.arg object} must be an onnx_model, onnx_fit, or an ONNX file path.")
  }
  object <- ensure_active_session(object)
  info <- cpp_model_info(SessionPointer(object))
  classification <- info$task_type != "regression"
  list(
    model = tibble(
      producer = info$producer, ir_version = info$ir_version,
      opset = info$opset, ml_opset = info$ml_opset, task = info$task_type,
      source_class = info$source_class, nodes = info$num_graph_nodes,
      tree_nodes = info$num_nodes, trees = info$num_trees
    ),
    inputs = tibble(name = info$input_name, element_type = "float32",
                    shape = list(c(NA_integer_, length(info$feature_names)))),
    outputs = tibble(
      name = info$output_names,
      element_type = if(classification) c(info$label_type, "float32") else "float32",
      shape = if(classification){
        list(c(NA_integer_), c(NA_integer_, length(info$class_levels)))
      } else list(c(NA_integer_, 1L))
    ),
    features = tibble(index = seq_along(info$feature_names) - 1L,
                      name = info$feature_names),
    engine = tibble(name = "native_c", execution_provider = "cpu",
                    openmp = info$openmp, inter_op_threads = 1L)
  )
}
