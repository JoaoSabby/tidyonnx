# Deterministic models measure both conversion cost and supported prediction paths.
onnx_internal_benchmark_fedora <- function(evidence) {
  set.seed(812)
  x <- matrix(rnorm(360L * 4L), ncol = 4L,
    dimnames = list(NULL, c("temperature", "rainfall", "altitude", "soil")))
  x[sample(length(x), 80L)] <- NA_real_
  signal <- rowSums(replace(x, is.na(x), 0))
  training <- xgboost::xgb.DMatrix(x, label = as.numeric(signal > 0), nthread = 1L)
  measurements <- list()
  for (rounds in c(15L, 300L)) {
    engine <- xgboost::xgb.train(list(objective = "binary:logistic", max_depth = 3L,
      eta = 0.2, nthread = 1L, base_score = 0.3), training,
      nrounds = rounds, verbose = 0L)
    allocation_file <- file.path(evidence, paste0("conversion-memory-", rounds, ".txt"))
    Rprofmem(allocation_file)
    elapsed <- system.time(model <- tidyonnx::onnx_convert(engine))[["elapsed"]]
    Rprofmem(NULL)
    allocated <- sum(suppressWarnings(as.numeric(sub(" .*", "",
      readLines(allocation_file, warn = FALSE)))), na.rm = TRUE)
    for (rows in c(1L, 100000L)) {
      input <- x[rep(seq_len(nrow(x)), length.out = rows), , drop = FALSE]
      engine_input <- xgboost::xgb.DMatrix(input, nthread = 1L)
      reference <- as.numeric(stats::predict(engine, engine_input))
      observed <- tidyonnx::onnx_predict(model, input, "numeric")$.pred
      difference <- max(abs(reference - observed))
      if (difference > 5e-6) stop("Benchmark numerical comparison failed.")
      repeats <- if (rows == 1L) 100L else 3L
      tidy_time <- system.time(for (index in seq_len(repeats)) {
        tidyonnx::onnx_predict(model, input, "raw")
      })[["elapsed"]] / repeats
      tensor_time <- system.time(for (index in seq_len(repeats)) {
        tidyonnx::onnx_run(model, list(features = input))
      })[["elapsed"]] / repeats
      engine_time <- system.time(for (index in seq_len(repeats)) {
        stats::predict(engine, engine_input)
      })[["elapsed"]] / repeats
      measurements[[length(measurements) + 1L]] <- data.frame(rounds, rows,
        conversion_seconds = elapsed, conversion_r_allocated_bytes = allocated,
        tidy_seconds = tidy_time, tensor_seconds = tensor_time,
        xgboost_seconds = engine_time, max_abs_xgboost = difference)
    }
  }
  utils::write.csv(do.call(rbind, measurements),
    file.path(evidence, "benchmarks.csv"), row.names = FALSE)
}
