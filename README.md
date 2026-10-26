# tidyonnx

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/JoaoSabby/tidyonnx/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/JoaoSabby/tidyonnx/actions/workflows/R-CMD-check.yaml)
[![R version](https://img.shields.io/badge/R-%3E%3D%204.3.0-blue)](https://cran.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)
<!-- badges: end -->

**tidyonnx** converts fitted numerical XGBoost tree ensembles to ONNX and performs
CPU prediction with a bundled C engine. Native models use S7 ownership and return
prediction tibbles. Fitted parsnip models and workflows can be converted directly
after training, preserving their preprocessing and outcome labels.

```r
fittedWorkflow |>
  onnx_convert() |>
  predict(new_data = testData, type = "prob")
```

Conversion occupies the same post-fit pipeline position as `butcher()`: fitting
and model selection finish first, then a prediction object is prepared for
storage and deployment. A converted fit is an `onnx_fit` bundle containing the
native ensemble and the R preprocessing required by `predict()`. The fitted
XGBoost engine is removed. Recipes and formula transformations remain in R.

## Installation

R 4.3 or later and a matching development toolchain are required for a source
installation. No external inference library or schema compiler is required.
The bundled C and C++ sources are compiled during installation. Optional OpenMP
support follows the R toolchain configuration.

```r
install.packages("remotes")
library(remotes)
install_github("JoaoSabby/tidyonnx")
```

To install the reviewed revision before merging, pass
`ref = "review/native-tidymodels-audit"` to `install_github()`.

`xgboost` is required for conversion. Direct prediction and ONNX loading do not
load it. `parsnip`, `workflows`, and `hardhat` are optional integration packages.
A converted bundle requires the packages used by its retained preprocessing.

## Without tidymodels

This multiclass example uses penguin measurements from `modeldata`. Training and
test rows are separated before fitting. Both feature names and target levels
are retained in the graph.

```r
library(tidyonnx)
library(modeldata)
library(xgboost)

data("penguins", package = "modeldata")
predictorNames <- c("bill_length_mm", "bill_depth_mm", "flipper_length_mm", "body_mass_g")
modelData <- na.omit(penguins[c("species", predictorNames)])

set.seed(2026)
trainRows <- sample.int(nrow(modelData), floor(0.8 * nrow(modelData)))
trainData <- modelData[trainRows, ]
testData <- modelData[-trainRows, ]

trainMatrix <- xgb.DMatrix(
  as.matrix(trainData[predictorNames]),
  label = as.integer(trainData$species) - 1L,
  nthread = 1L
)
fittedModel <- xgb.train(
  list(
    objective = "multi:softprob",
    num_class = nlevels(trainData$species),
    max_depth = 3L,
    eta = 0.1,
    nthread = 1L
  ),
  trainMatrix,
  nrounds = 20L,
  verbose = 0L
)

nativeModel <- onnx_convert(
  fittedModel,
  params = list(class_levels = levels(trainData$species))
)
predict(nativeModel, testData[predictorNames], type = "prob")
predict(nativeModel, testData[predictorNames], type = "class")
onnx_inspect(nativeModel)
```

## With tidymodels

A fitted workflow can be converted directly. Its trained recipe is applied to
original predictor data at prediction time. No manual `bake()` call is required.

```r
library(tidyonnx)
library(modeldata)
library(parsnip)
library(recipes)
library(workflows)

data("penguins", package = "modeldata")
modelData <- penguins[c(
  "species", "island", "bill_length_mm", "bill_depth_mm",
  "flipper_length_mm", "body_mass_g"
)]

set.seed(2026)
trainRows <- sample.int(nrow(modelData), floor(0.8 * nrow(modelData)))
trainData <- modelData[trainRows, ]
testData <- modelData[-trainRows, ]

recipeSpec <- recipe(species ~ ., data = trainData) |>
  step_impute_median(all_numeric_predictors()) |>
  step_dummy(all_nominal_predictors())

modelSpec <- boost_tree(trees = 20, tree_depth = 3, learn_rate = 0.1) |>
  set_engine("xgboost", nthread = 1) |>
  set_mode("classification")

fittedWorkflow <- workflow() |>
  add_recipe(recipeSpec) |>
  add_model(modelSpec) |>
  fit(data = trainData)

convertedWorkflow <- fittedWorkflow |> onnx_convert()
predict(convertedWorkflow, testData, type = "prob")
predict(convertedWorkflow, testData)

stopifnot(isTRUE(all.equal(
  predict(fittedWorkflow, testData, type = "prob"),
  predict(convertedWorkflow, testData, type = "prob"),
  tolerance = 5e-6
)))
```

Direct parsnip fits are also supported, including formula preprocessing:

```r
fittedParsnip <- modelSpec |>
  fit(species ~ bill_length_mm + bill_depth_mm + island, data = na.omit(trainData))
convertedParsnip <- onnx_convert(fittedParsnip)
predict(convertedParsnip, na.omit(testData), type = "prob")
```

Existing butcher pipelines remain valid:

```r
library(butcher)

reducedWorkflow <- fittedWorkflow |>
  butcher() |>
  onnx_convert()
predict(reducedWorkflow, testData, type = "prob")
```

Classification bundles default to `.pred_class`, matching parsnip and workflows.
Native classification models default to `.pred_{level}` probability columns.
Binary parsnip event ordering is preserved for both `event_level = "first"` and
`event_level = "second"`. Multiclass output retains the original outcome order.
Workflows with postprocessors and unsupported engine objectives are rejected.

## Prediction contract

| Type | Regression | Classification |
| --- | --- | --- |
| `"numeric"` | Tibble with `.pred` | Positive-class probability for native binary models |
| `"prob"` | Rejected | Tibble with `.pred_{level}` columns |
| `"class"` | Rejected | Factor column `.pred_class` |
| `"raw"` | Numeric response vector | Native score matrix; binary bundles return encoded-positive probability vectors |

Raw output describes formatting, not a request for pre-activation margins.
Multiclass models and classification bundles reject `type = "numeric"`.
External ONNX graphs retain their declared score transformation, so their raw
scores are not guaranteed to be normalized probabilities.

Native inference accepts plain integer and double matrices, data frames, and
tibbles. Named features are aligned to the saved order. Extra data-frame columns
are ignored; matrices require the exact model width. Unnamed matrices must
already use engine order. Missing values follow stored split directions.
Factors and other classed columns require prior encoding; infinite values,
missing features, and duplicate names are rejected. Empty batches preserve the
output schema. Converted preprocessing must produce dense numerical predictors;
sparse matrices are rejected.

## Persistence

Bare numerical ensembles use portable ONNX files:

```r
modelFile <- tempfile(fileext = ".onnx")
onnx_save(nativeModel, modelFile)
restoredModel <- onnx_load(modelFile)
predict(restoredModel, as.matrix(testData[predictorNames]), type = "prob")
unlink(modelFile)
```

Workflow and parsnip bundles retain R preprocessing and use RDS:

```r
bundleFile <- tempfile(fileext = ".rds")
saveRDS(convertedWorkflow, bundleFile)
restoredWorkflow <- readRDS(bundleFile)
predict(restoredWorkflow, testData, type = "prob")
unlink(bundleFile)
```

`onnx_save()` rejects bundles to prevent loss of preprocessing. An extracted
engine can be converted explicitly when the consumer supplies already encoded
predictors. The R preprocessing in a bundle is never represented as an ONNX graph.

Embedded model bytes allow lazy session restoration after RDS deserialization.
With `onnx_load(modelFile, params = list(embed_raw_bytes = FALSE))`, the backing
file must remain available and retain its saved checksum. Replaced files are
rejected even if their feature schema is unchanged. Checksums detect accidental
replacement; they do not authenticate artifacts from untrusted sources.

## Coverage and execution

| XGBoost objective | Graph | Response |
| --- | --- | --- |
| `binary:logistic` | TreeEnsembleClassifier | Two complementary probabilities |
| `binary:logitraw` | TreeEnsembleRegressor | Raw margin |
| `reg:squarederror` | TreeEnsembleRegressor | Numeric response |
| `reg:logistic` | TreeEnsembleRegressor + Sigmoid | Logistic response |
| `multi:softprob` | TreeEnsembleClassifier | Class probabilities |
| `multi:softmax` | TreeEnsembleClassifier | Probabilities or argmax class |

Conversion supports numerical `gbtree` models, including parallel trees. A saved
early-stopping best iteration is honored by default, preserving the default
XGBoost prediction range. Use `params = list(iteration_range = "all")` to export
every stored iteration explicitly. Observation
base margins and custom objective behavior cannot be recovered from the graph.
Categorical splits, vector leaves, DART, linear boosters, and multi-output
regression are rejected. Converted classifiers include a constant intercept tree
for portable class-score semantics.

Loading supports one numerical ONNX-ML tree node, optionally followed by Sigmoid
for regression, with one dynamic-row float32 input. IR versions 3 through 10 and
ML opsets 1 through 3 are supported within this subset. Initializers, arbitrary
preprocessing graphs, ZipMap, tensor attributes, single-score binary classifiers,
and nonzero binary base-value arrays are rejected.

```r
onnx_predict(nativeModel, as.matrix(testData[predictorNames]),
             params = list(intra_op_threads = 4L))
onnx_inspect(nativeModel)$engine
```

Workers are limited per inference call. Automatic core detection is cached and
bounded to 1024; small batches use fewer workers. Builds without OpenMP run
serially. No global OpenMP settings are changed. Feature buffers are borrowed;
output, pointer tables, and thread workspace still allocate. Numerical equality
is assessed with explicit float32 tolerances.

All public operations accept a named `params` list. `?onnx_parameters` documents
every default and its scope. Only CPU and float32 graphs are supported.
`graph_opt_level` and `log_severity` are validated compatibility settings without
graph optimization or logging behavior in the bundled engine.

## Citation

```r
citation("tidyonnx")
```

João B. G. de Brito (2026). *tidyonnx: Native ONNX Serialization and Prediction
for Fitted Tree Models*. R package. <https://github.com/JoaoSabby/tidyonnx>.

## Development

Documentation is generated from the English roxygen2 headers of public and
internal R functions. Applicable tags describe arguments, behavior, return types,
examples, cross-references, and primary technical references.

```r
library(testthat)
test_local()
source("tools/document.R")
```

Run `R CMD build .` and `R CMD check --no-manual tidyonnx_0.1.1.tar.gz` after
installing all suggested packages. CI checks Linux, Windows, and macOS. See
[REVIEW.md](REVIEW.md) for the audit findings, [ARCHITECTURE.md](ARCHITECTURE.md)
for implementation boundaries, and [VALIDATION.md](VALIDATION.md) for measured
checks and their limitations.
