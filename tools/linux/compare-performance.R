# Retain raw samples and report compiler ratios only together with numerical correctness.
directory <- commandArgs(trailingOnly = TRUE)[[1L]]
files <- list.files(directory, pattern = "^(gcc|intel-makevars001)-[0-9]+-timings[.]csv$", full.names = TRUE)
stopifnot(length(files) >= 2L)
samples <- do.call(rbind, lapply(files, read.csv))
checks <- do.call(rbind, lapply(list.files(directory,
  pattern = "^(gcc|intel-makevars001)-[0-9]+-correctness[.]csv$", full.names = TRUE), read.csv))
stopifnot(nrow(checks) > 0L, !anyDuplicated(samples[c("profile", "block", "repetition", "case")]))
groups <- split(samples, interaction(samples$profile, samples$case, drop = TRUE))
summary <- do.call(rbind, lapply(groups, function(group) {
  data.frame(profile = group$profile[[1L]], case = group$case[[1L]],
    trees = group$trees[[1L]], rows = group$rows[[1L]], threads = group$threads[[1L]],
    output = group$output[[1L]], samples = nrow(group),
    median_seconds = median(group$seconds), iqr_seconds = IQR(group$seconds),
    minimum_seconds = min(group$seconds), maximum_seconds = max(group$seconds))
}))
comparison <- merge(summary[summary$profile == "gcc", ],
  summary[summary$profile == "intel-makevars001", ],
  by = c("case", "trees", "rows", "threads", "output"), suffixes = c("_gcc", "_intel"),
  all = TRUE)
stopifnot(nrow(comparison) == length(unique(samples$case)),
  all(is.finite(comparison$median_seconds_gcc)),
  all(is.finite(comparison$median_seconds_intel)))
comparison$timer_resolved <- comparison$median_seconds_gcc > 0 & comparison$median_seconds_intel > 0
comparison$gcc_over_intel <- ifelse(comparison$timer_resolved,
  comparison$median_seconds_gcc / comparison$median_seconds_intel, NA_real_)
comparison$all_predictions_exact <- all(checks$exact)
write.csv(samples, file.path(directory, "all-timings.csv"), row.names = FALSE)
write.csv(checks, file.path(directory, "all-correctness.csv"), row.names = FALSE)
write.csv(comparison, file.path(directory, "performance-comparison.csv"), row.names = FALSE)
jsonlite::write_json(comparison, file.path(directory, "performance-comparison.json"),
  pretty = TRUE, digits = 17L, na = "null")
writeLines(c("# Compiler performance comparison", "",
  "Ratio = median GCC seconds / median Intel seconds; values above 1 favor Intel.",
  "The measurements include the public R API and automatic garbage collection.",
  "Model training, process startup, file output, and compilation are excluded from API timings.",
  "Compilation wall times are recorded separately in build-seconds.csv.",
  paste("All saved prediction checks exact:", all(checks$exact)),
  "If exactness fails, speed ratios are diagnostic and do not establish an acceptable build.",
  "These are observed results for this runner, not a general compiler ranking."),
  file.path(directory, "performance-methodology.md"))
print(comparison[, c("case", "median_seconds_gcc", "median_seconds_intel",
  "gcc_over_intel", "all_predictions_exact")], row.names = FALSE)
if (!all(checks$exact)) stop("Prediction equality failed; retain timings as diagnostic evidence.")
if (!all(comparison$timer_resolved)) stop("Timer resolution insufficient; increase BENCH_SECONDS and repeat in a fresh output directory.")
