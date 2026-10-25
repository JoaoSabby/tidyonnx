\name{onnx_save}
\alias{onnx_save}
\alias{onnx_load}
\alias{onnx_convert}
\alias{onnx_predict}
\alias{onnx_inspect}
\alias{predict.tidyonnx::onnx_model}
\alias{print.tidyonnx::onnx_model}
\title{Convert, Save, Load, Predict, and Inspect ONNX Tree Models}
\description{
Converts numerical XGBoost tree ensembles to standard binary ONNX graphs,
loads supported ONNX-ML tree graphs, and evaluates them with a native C engine.
Native resources are managed automatically by S7 and cpp11.
}
\usage{
onnx_save(model, file, feature_names = NULL, params = list())

onnx_load(file, params = list())

onnx_convert(model, feature_names = NULL, params = list())

onnx_predict(object, new_data, type = NULL, params = list())

onnx_inspect(object, params = list())
}
\arguments{
\item{model}{An \code{xgb.Booster} with a supported built-in objective, or an
existing tidyonnx S7 model.}
\item{file}{One file path. The parent directory must exist.}
\item{feature_names}{Optional unique predictor names, one per training feature.
Defaults to the stored names, or \code{f0}, \code{f1}, and so on.
Names and class labels cannot contain line breaks.}
\item{params}{A uniquely named list. Unknown names and unsupported values fail.
See Details for the complete supported settings.}
\item{object}{An S7 model returned by \code{onnx_load()} or
\code{onnx_convert()}, or one ONNX file path.}
\item{new_data}{A numeric/integer matrix, data frame, or tibble. Named columns
are aligned to the model feature order. Extra data-frame columns are ignored.
Unnamed matrices must already use training order. Missing values follow the
stored tree directions. Infinite values and non-numeric predictors fail.}
\item{type}{One of \code{"prob"}, \code{"class"}, \code{"numeric"}, or
\code{"raw"}. The default is \code{"prob"} for classification and
\code{"numeric"} for regression. Raw means unformatted output, not a margin.}
}
\value{
\code{onnx_save()} returns the normalized destination path invisibly.
\code{onnx_load()} and \code{onnx_convert()} return an S7 model.
\code{onnx_predict()} returns a tibble, except for \code{type = "raw"}, which
returns a numeric vector for regression or a probability matrix for
classification. Probability columns are named \code{.pred_\{level\}}.
Numeric output is named \code{.pred}; binary numeric output is the positive
class probability. Class output is a factor column named \code{.pred_class}.
Multiclass numeric output and regression class/probability output are rejected.
\code{onnx_inspect()} returns a named list of tibbles describing the model,
inputs, outputs, features, and actual engine capabilities.
}
\details{
Supported objectives are \code{binary:logistic}, \code{binary:logitraw},
\code{reg:squarederror}, \code{reg:logistic}, \code{multi:softprob}, and
\code{multi:softmax}. Conversion exports all stored trees from numerical
\code{gbtree} boosters. Categorical splits, DART, linear boosters, vector
leaves, and multiple regression targets are unsupported.

Classification defaults to class levels \code{"0"}, \code{"1"}, and so on.
Binary class predictions select the positive class at probability 0.5.
Multiclass ties select the first class. \code{multi:softmax} graphs still
expose probabilities; use \code{type = "class"} for argmax labels.

Supported parameter settings are:
\describe{
\item{\code{target_opset = 18L}}{Standard ONNX opset written at conversion,
between 18 and 21. ML opset is always 3.}
\item{\code{ir_version = 8L}}{Model IR version written at conversion, 8 to 10.}
\item{\code{float_precision = "float32"}}{Only float32 is supported.}
\item{\code{embed_raw_bytes = TRUE}}{Embed bytes when loading from disk.
In-memory conversions always retain bytes.}
\item{\code{class_levels = NULL}}{Optional character vector of unique class
labels in target order. NULL derives labels from class count.}
\item{\code{execution_provider = "cpu"}}{Only CPU is supported.}
\item{\code{intra_op_threads = 0L}}{Maximum workers, 0 to 1024. Zero requests
the detected physical-core count, with a fallback to one. Small batches and
builds without OpenMP execute serially.}
\item{\code{inter_op_threads = 1L}}{Only one graph node is evaluated.}
\item{\code{graph_opt_level = "all"}}{Accepts \code{"all"} and
\code{"disable"}; neither performs graph rewrites in this engine.}
\item{\code{log_severity = "error"}}{Validated compatibility setting accepting
verbose, info, warning, error, or fatal. The native engine reports errors only.}
}

Parameter lists apply to the current call. Serialization settings affect
conversion; thread settings affect prediction. There are no global mutable
runtime options. These functions do not use an ONNX Runtime session.

RDS persistence retains portable bytes by default and restores native resources
lazily. With \code{embed_raw_bytes = FALSE}, the original file must remain
readable. A different file with the same schema can change restored predictions.

External ONNX support is restricted to a single numerical TreeEnsemble node,
optionally followed by a standard Sigmoid for regression, one float32 input of shape [N,P] with dynamic rows and known width, SUM
aggregation, and NONE, LOGISTIC, or SOFTMAX transforms. Classifiers require
explicit per-class scores. Nonzero two-class base values, single-score binary
classifiers, tensor attributes, initializers, ZipMap, preprocessing, and
multi-output regression are rejected. Classifier conversion adds a constant
intercept tree, visible in inspection, for portable score semantics.

Prediction borrows ordinary R column storage. ALTREP vectors may materialize
before evaluation. Output and thread workspace still allocate. Numerical
equivalence is at float32 tolerance, rather than guaranteed bitwise identity.
}
\examples{
if (requireNamespace("xgboost", quietly = TRUE)) {
  x <- as.matrix(iris[1:100, 1:4])
  y <- as.integer(iris$Species[1:100] == "versicolor")
  training <- xgboost::xgb.DMatrix(x, label = y, nthread = 1L)
  fit <- xgboost::xgb.train(
    list(objective = "binary:logistic", max_depth = 2L,
         nthread = 1L, base_score = 0.3),
    training, nrounds = 3L, verbose = 0L
  )
  file <- tempfile(fileext = ".onnx")
  onnx_save(fit, file)
  model <- onnx_load(file)
  onnx_predict(model, x[1:3, , drop = FALSE])
  predict(model, x[1:3, , drop = FALSE], type = "class")
  onnx_inspect(model)
  unlink(file)
}
}
\seealso{
\code{stats::predict()}, \code{saveRDS()}, \code{readRDS()}
}
