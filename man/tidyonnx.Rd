\name{tidyonnx}
\alias{tidyonnx}
\alias{tidyonnx-package}
\docType{package}
\title{Native ONNX Tree Ensemble Serialization and Inference}
\description{
Serializes numerical XGBoost ensembles into ONNX and evaluates a documented
subset of ONNX-ML tree graphs through a self-contained C engine.
The R interface uses S7 model objects and predictable tibble outputs.
}
\details{
Only CPU inference is implemented. The package includes Nanopb sources and
does not require an external inference library or a protobuf compiler.
See \code{\link{onnx_save}} for the public API and supported objectives.
}
