# Use the model's stable UTF-8 JSON representation, without temporary files.
onnx_internal_xgboost_document <- function(model) {
  document_text <- rawToChar(xgboost::xgb.save.raw(model, raw_format = "json"))
  Encoding(document_text) <- "UTF-8"
  jsonlite::fromJSON(document_text, simplifyVector = FALSE)$learner
}
