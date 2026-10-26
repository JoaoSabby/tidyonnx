#' @rdname onnx_convert
#' @export
onnx_convert.model_fit <- function(model, feature_names = NULL, params = list(), ...){
  check_dots_empty()
  params <- validate_onnx_params(params)
  CheckOptionalPackage("parsnip")
  if(!identical(model$spec$engine, "xgboost") || !inherits(model$fit, "xgb.Booster")){
    cli_abort("A fitted parsnip model with an xgboost engine is required.")
  }
  if(!model$spec$mode %in% c("classification", "regression")){
    cli_abort("Only classification and regression parsnip fits are supported.")
  }
  eventFirst <- FALSE
  if(model$spec$mode == "classification" && length(model$lvl) == 2L){
    probabilityPost <- model$spec$method$pred$prob$post
    if(!is.function(probabilityPost)){
      cli_abort("The fitted binary probability mapping is unavailable.")
    }
    mappedLevels <- probabilityPost(c(0, 1), model)
    eventFirst <- identical(as.numeric(mappedLevels[[1L]]), c(0, 1))
  }
  nativeModel <- ConvertBooster(model$fit, feature_names, params, model$lvl, eventFirst)
  if((model$spec$mode == "classification") != (nativeModel@task_type != "regression")){
    cli_abort("The engine objective is incompatible with the parsnip prediction mode.")
  }
  predictionSpec <- structure(
    list(mode = model$spec$mode, engine = model$spec$engine,
         method = list(fit = list(interface = model$spec$method$fit$interface))),
    class = class(model$spec)
  )
  template <- structure(list(preproc = model$preproc, spec = predictionSpec),
                        class = "model_fit")
  structure(
    list(model = nativeModel, template = template, blueprint = NULL,
         levels = model$lvl, mode = model$spec$mode),
    class = "onnx_fit"
  )
}

#' @rdname onnx_convert
#' @export
onnx_convert.workflow <- function(model, feature_names = NULL, params = list(), ...){
  check_dots_empty()
  CheckOptionalPackage("workflows")
  CheckOptionalPackage("hardhat")
  ExtractFit <- getExportedValue("workflows", "extract_fit_parsnip")
  ExtractMold <- getExportedValue("workflows", "extract_mold")
  if(length(model$post$actions)){
    cli_abort("Workflow postprocessors cannot be represented by this converter.")
  }
  converted <- onnx_convert(ExtractFit(model), feature_names, params)
  converted$blueprint <- ExtractMold(model)$blueprint
  converted
}

#' @rdname onnx_convert
#' @export
onnx_convert.onnx_fit <- function(model, feature_names = NULL, params = list(), ...){
  check_dots_empty()
  model$model <- onnx_convert(model$model, feature_names, params)
  model
}

#' @title Predict from a converted parsnip model or workflow
#' @description
#' Retained preprocessing is applied before prediction with the native ensemble.
#' @details
#' Workflow inputs are forged with their trained hardhat blueprint. The exported
#' parsnip prepare_data function then applies the fitted formula or matrix
#' encoding. Probability columns and factor levels follow the original outcome.
#' @param object An onnx_fit bundle returned by [onnx_convert()].
#' @param new_data Original predictor data, before recipe or formula preprocessing.
#' @param type Prediction type. NULL selects class for classification and numeric
#'   for regression. Other supported values are prob and raw.
#' @param ... Reserved for future extensions; must be empty.
#' @param params A named list of inference settings; see [onnx_parameters].
#' @return A prediction tibble, or an unformatted vector or matrix for raw output.
#'   Binary bundle raw predictions are encoded-positive-class probability vectors.
#' @seealso [onnx_predict()], [onnx_convert()]
#' @references <https://parsnip.tidymodels.org/reference/predict.model_fit.html>
#' @export
predict.onnx_fit <- function(object, new_data, type = NULL, ..., params = list()){
  check_dots_empty()
  validate_onnx_params(params)
  CheckOptionalPackage("parsnip")
  if(!is.null(object$blueprint)){
    CheckOptionalPackage("hardhat")
    Forge <- getExportedValue("hardhat", "forge")
    new_data <- Forge(new_data, blueprint = object$blueprint)$predictors
  }
  PrepareData <- getExportedValue("parsnip", "prepare_data")
  new_data <- PrepareData(object$template, new_data)
  if(is.null(type)) type <- if(object$mode == "classification") "class" else "numeric"
  if(object$mode == "classification" && identical(type, "numeric")){
    cli_abort("Use class, prob, or raw for a classification bundle.")
  }
  result <- onnx_predict(object$model, new_data, type, params)
  if(identical(type, "raw") && object$model@task_type == "classification_binary"){
    return(result[, 2L])
  }
  if(identical(type, "prob")){
    result <- result[str_c(".pred_", object$levels)]
  } else if(identical(type, "class")){
    result$.pred_class <- factor(result$.pred_class, levels = object$levels)
  }
  result
}

#' @title Print a converted prediction bundle
#' @description
#' The retained preprocessing mode and native ensemble structure are displayed.
#' @param x An onnx_fit bundle.
#' @param ... Reserved arguments; ignored for print compatibility.
#' @return The bundle, invisibly, after its summary has been printed.
#' @seealso [onnx_inspect()], [print.onnx_model()]
#' @references <https://stat.ethz.ch/R-manual/R-devel/library/base/html/print.html>
#' @export
print.onnx_fit <- function(x, ...){
  cat("<tidyonnx prediction bundle>\n")
  cat("Preprocessing: ", if(is.null(x$blueprint)) "parsnip" else "workflow", "\n", sep = "")
  print(x$model)
  invisible(x)
}

#' @title Require an optional integration package
#' @description
#' Package availability is checked without attaching a namespace or installing it.
#' @param package A scalar package name.
#' @return TRUE invisibly, or an informative error when the package is unavailable.
#' @seealso [requireNamespace()]
#' @references <https://stat.ethz.ch/R-manual/R-devel/library/base/html/ns-load.html>
#' @keywords internal
CheckOptionalPackage <- function(package){
  if(!requireNamespace(package, quietly = TRUE)){
    cli_abort("Install {.pkg {package}} to use this operation.")
  }
  invisible(TRUE)
}
