# Measure only public API operations; fitting, process startup, and disk output are excluded.
arguments <- commandArgs(trailingOnly = TRUE)
directory <- arguments[[1L]]
profile <- arguments[[2L]]
block <- as.integer(arguments[[3L]])
fixture <- readRDS(file.path(directory, "fixture.rds"))
inputs <- readRDS(file.path(directory, "inputs.rds"))
repetitions <- as.integer(Sys.getenv("BENCH_REPETITIONS", "7"))
target_seconds <- as.numeric(Sys.getenv("BENCH_SECONDS", "0.08"))
stopifnot(repetitions >= 2L, block >= 1L, is.finite(target_seconds), target_seconds >= 0.05)
timing_plan <- file.path(directory, "iteration-plan.rds")
iterations_by_case <- if (file.exists(timing_plan)) readRDS(timing_plan) else list()

# Warm up each operation, calibrate on GCC, and reuse exactly the same call count on Intel.
onnx_internal_benchmark_measure <- function(operation, case, trees, rows, threads, output) {
  invisible(lapply(seq_len(2L), function(index) operation()))
  if (is.null(iterations_by_case[[case]])) {
    stopifnot(profile == "gcc")
    # Calibrate whole batches rather than dividing a single clock tick by tiny calls.
    pilot <- Reduce(function(state, count) {
      if (state$elapsed >= target_seconds) return(state)
      elapsed <- unname(system.time(invisible(lapply(seq_len(count), function(index) {
        invisible(operation())
        NULL
      })))[["elapsed"]])
      list(iterations = count, elapsed = elapsed)
    }, c(1L, 10L, 100L, 1000L, 10000L), init = list(iterations = 0L, elapsed = 0))
    iterations_by_case[[case]] <<- pilot$iterations
  }
  iterations <- iterations_by_case[[case]]
  elapsed <- vapply(seq_len(repetitions), function(index) {
    invisible(gc())
    start <- proc.time()[["elapsed"]]
    # Both profiles include the same functional-call overhead and any automatic GC.
    invisible(lapply(seq_len(iterations), function(iteration) {
      invisible(operation())
      NULL
    }))
    (proc.time()[["elapsed"]] - start) / iterations
  }, numeric(1))
  data.frame(profile = profile, block = block, repetition = seq_len(repetitions),
    case = case, trees = trees, rows = rows, threads = threads, output = output,
    iterations = iterations, seconds = elapsed)
}

results <- lapply(fixture$trees, function(trees) {
  stem <- file.path(directory, paste0("trees-", trees))
  model <- tidyonnx::onnx_load(paste0(stem, ".onnx"))
  source <- xgboost::xgb.load(paste0(stem, ".ubj"))
  reference <- readRDS(paste0(stem, "-reference.rds"))
  batch_sizes <- unique(c(1L, 1000L, fixture$rows))
  grid <- expand.grid(rows = batch_sizes, threads = c(1L, 2L),
    output = c("prob", "raw"), stringsAsFactors = FALSE)
  predictions <- lapply(seq_len(nrow(grid)), function(index) {
    scenario <- grid[index, ]
    batch <- inputs[seq_len(scenario$rows), , drop = FALSE]
    operation <- function() tidyonnx::onnx_predict(model, batch, type = scenario$output,
      params = list(intra_op_threads = scenario$threads))
    actual <- as.matrix(operation())
    expected <- reference[seq_len(scenario$rows)]
    # Raw graph output has a float32 complement; compare the source's positive probability.
    exact <- identical(as.numeric(actual[, 2L]), expected)
    if (scenario$output == "prob") exact <- exact &&
      identical(as.numeric(actual[, 1L]), 1 - expected)
    diagnostic <- data.frame(profile = profile, block = block, trees = trees,
      rows = scenario$rows, threads = scenario$threads, output = scenario$output,
      exact = exact, max_difference = max(abs(actual[, 2L] - expected)))
    write.table(diagnostic, file.path(directory, paste0(profile, "-", block, "-correctness.csv")),
      sep = ",", row.names = FALSE, col.names = index == 1L && trees == fixture$trees[[1L]],
      append = !(index == 1L && trees == fixture$trees[[1L]]))
    case <- paste("predict", trees, scenario$rows, scenario$threads, scenario$output, sep = "-")
    onnx_internal_benchmark_measure(operation, case, trees, scenario$rows,
      scenario$threads, scenario$output)
  })
  # Conversion and graph loading are timed separately from steady-state inference.
  loading <- onnx_internal_benchmark_measure(
    function() tidyonnx::onnx_load(paste0(stem, ".onnx")),
    paste0("load-", trees), trees, NA_integer_, NA_integer_, "model")
  conversion <- onnx_internal_benchmark_measure(
    function() tidyonnx::onnx_convert(source,
      params = list(class_levels = c("absence", "presence"))),
    paste0("convert-", trees), trees, NA_integer_, NA_integer_, "model")
  do.call(rbind, c(predictions, list(loading, conversion)))
})
results <- do.call(rbind, results)
write.csv(results, file.path(directory, paste0(profile, "-", block, "-timings.csv")),
  row.names = FALSE)
if (profile == "gcc") saveRDS(iterations_by_case, timing_plan)
writeLines(c(paste("loaded package:", find.package("tidyonnx")),
  capture.output(sessionInfo())), file.path(directory, paste0(profile, "-", block, "-session.txt")))

