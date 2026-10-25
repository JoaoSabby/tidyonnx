# Inspection reports actual engine capabilities alongside portable graph metadata.
onnx_inspect <- function(object, params = list()) {
  validate_onnx_params(params)
  if (is.character(object) && length(object) == 1L) object <- onnx_load(object)
  if (!S7::S7_inherits(object, onnx_model)) {
    stop("object must be an onnx_model or an ONNX file path.", call. = FALSE)
  }
  object <- ensure_active_session(object)
  info <- cpp_model_info(object@session_ptr)
  classification <- info$task_type != "regression"
  list(
    model = tibble::tibble(producer = info$producer, ir_version = info$ir_version,
      opset = info$opset, ml_opset = info$ml_opset, task = info$task_type,
      source_class = info$source_class, nodes = info$num_graph_nodes, tree_nodes = info$num_nodes, trees = info$num_trees),
    inputs = tibble::tibble(name = info$input_name, element_type = "float32",
      shape = list(c(NA_integer_, length(info$feature_names)))),
    outputs = tibble::tibble(name = info$output_names,
      element_type = if (classification) c(info$label_type, "float32") else "float32",
      shape = if (classification) list(c(NA_integer_), c(NA_integer_, length(info$class_levels))) else
        list(c(NA_integer_, 1L))),
    features = tibble::tibble(index = seq_along(info$feature_names) - 1L,
      name = info$feature_names),
    engine = tibble::tibble(name = "native_c", execution_provider = "cpu",
      openmp = info$openmp, inter_op_threads = 1L)
  )
}
