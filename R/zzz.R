# Register source adapters and public operations after all namespace bindings exist.
.onLoad <- function(libname, pkgname) {
  S7::method(onnx_convert, S7::class_any) <- onnx_internal_convert_default
  S7::method(onnx_convert, S7::new_S3_class("xgb.Booster")) <- onnx_internal_convert_xgboost
  S7::method(onnx_convert, S7::new_S3_class("model_fit")) <- onnx_internal_convert_parsnip
  S7::method(onnx_convert, S7::new_S3_class("workflow")) <- onnx_internal_convert_workflow
  S7::method(onnx_save, S7::class_any) <- onnx_internal_save
  S7::method(onnx_load, S7::class_any) <- onnx_internal_load
  S7::method(onnx_predict, S7::class_any) <- onnx_internal_predict
  S7::method(onnx_inspect, S7::class_any) <- onnx_internal_inspect
  S7::method(onnx_save, onnx_internal_model) <- onnx_internal_save
  S7::method(onnx_predict, onnx_internal_model) <- onnx_internal_predict
  S7::method(onnx_predict, S7::class_character) <- onnx_internal_predict
  S7::method(onnx_inspect, onnx_internal_model) <- onnx_internal_inspect
  S7::method(onnx_inspect, S7::class_character) <- onnx_internal_inspect
  S7::method(onnx_load, S7::class_character) <- onnx_internal_load
  # S7 manages compatibility methods for the standard R generic functions.
  S7::method(predict, onnx_internal_model) <- onnx_internal_predict_method
  S7::method(print, onnx_internal_model) <- onnx_internal_print_method
  S7::methods_register()
}
