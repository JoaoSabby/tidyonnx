# Tensor metadata comes from the active runtime; optional tree counts remain provenance.
onnx_inspect <- function(object, params = list()) {
  onnx_internal_check_param_context(params, "inspect")
  onnx_internal_validate_onnx_params(params)
  if (is.character(object) && length(object) == 1L) object <- onnx_load(object, params)
  if (!S7::S7_inherits(object, onnx_model)) {
    stop("object must be an onnx_model or an ONNX file path.", call. = FALSE)
  }
  object <- onnx_internal_ensure_active_session(object,
    if (length(params)) onnx_internal_validate_onnx_params(params) else NULL)
  info <- onnx_internal_model_info(object@session_ptr)
  custom <- info$custom
  # Absent graph counts must remain unknown for arbitrary external models.
  onnx_internal_number <- function(name) {
    if (is.null(custom[[name]])) NA_real_ else as.numeric(custom[[name]])
  }
  # List columns retain arbitrary tensor ranks and unknown dimensions without guessing.
  onnx_internal_table <- function(tensors) {
    tibble::tibble(name = vapply(tensors, `[[`, "", "name"),
      kind = vapply(tensors, `[[`, "", "kind"),
      element_type = vapply(tensors, `[[`, "", "element_type"),
      shape = lapply(tensors, `[[`, "shape"), symbols = lapply(tensors, `[[`, "symbols"))
  }
  runtime <- utils::read.csv(system.file("ort", "runtime.csv", package = "tidyonnx"),
    stringsAsFactors = FALSE)
  list(model = tibble::tibble(producer = info$producer,
      ir_version = onnx_internal_number("ir_version"), opset = onnx_internal_number("opset"),
      ml_opset = onnx_internal_number("ml_opset"), task = object@task_type,
      source_class = object@source_class, target_name = object@target_name,
      nodes = onnx_internal_number("num_graph_nodes"),
      tree_nodes = onnx_internal_number("num_nodes"), trees = onnx_internal_number("num_trees")),
    inputs = onnx_internal_table(info$inputs), outputs = onnx_internal_table(info$outputs),
    features = tibble::tibble(index = seq_along(object@feature_names) - 1L,
      name = object@feature_names),
    engine = tibble::tibble(name = "onnxruntime", execution_provider = "cpu",
      version = info$runtime_version, api_version = info$api_version,
      asset = runtime$asset, archive_sha256 = runtime$sha256,
      library_sha256 = runtime$library_sha256,
      intra_op_threads = object@metadata$session_cache$params$intra_op_threads,
      inter_op_threads = object@metadata$session_cache$params$inter_op_threads))
}
