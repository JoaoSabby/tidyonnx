# Compare saved, unrounded probabilities and fail on numerical or class disagreement.
arguments <- commandArgs(trailingOnly = TRUE)
output_directory <- if (length(arguments)) arguments[[1L]] else "/artifacts"
reference <- readRDS(file.path(output_directory, "xgboost-predictions.rds"))
converted <- readRDS(file.path(output_directory, "onnx-predictions.rds"))
stopifnot(length(reference) == length(converted), all(is.finite(reference)),
  all(is.finite(converted)), all(reference >= 0 & reference <= 1),
  all(converted >= 0 & converted <= 1))
absolute_difference <- abs(reference - converted)
class_agreement <- (reference >= 0.5) == (converted >= 0.5)
tolerance <- 1e-6
summary <- list(
  source_revision = Sys.getenv("SOURCE_REVISION", unset = "local"),
  rows = length(reference), objective = "binary:logistic",
  exact_bitwise_equality = identical(reference, converted),
  exact_value_matches = sum(reference == converted),
  max_absolute_difference = max(absolute_difference),
  mean_absolute_difference = mean(absolute_difference),
  root_mean_squared_difference = sqrt(mean((reference - converted)^2)),
  absolute_tolerance = tolerance,
  numerically_equal = all(absolute_difference <= tolerance),
  class_matches = sum(class_agreement),
  classes_identical = all(class_agreement)
)
comparison <- data.frame(row_id = seq_along(reference), xgboost_probability = reference,
  onnx_probability = converted, absolute_difference = absolute_difference,
  xgboost_class = as.integer(reference >= 0.5), onnx_class = as.integer(converted >= 0.5))
saveRDS(comparison, file.path(output_directory, "prediction-comparison.rds"))
write.csv(comparison, file.path(output_directory, "prediction-comparison.csv"), row.names = FALSE)
jsonlite::write_json(summary, file.path(output_directory, "comparison-summary.json"),
  auto_unbox = TRUE, pretty = TRUE, digits = 17L)
print(summary)
# This deterministic acceptance fixture requires exact equality; tolerance is diagnostic only.
stopifnot(summary$exact_bitwise_equality, summary$classes_identical)
cat("Binary logistic equivalence: PASS. Exact bitwise equality:",
  summary$exact_bitwise_equality, "; maximum absolute difference:",
  format(summary$max_absolute_difference, digits = 17L), "\n")
