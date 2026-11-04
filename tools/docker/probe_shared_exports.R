# Diagnostic variants isolate ABI failures but can never approve a failed reference profile.
onnx_internal_probe_shared_exports <- function(settings, profile) {
  directory <- "/opt/tidyonnx/shared-export-diagnostics"
  dir.create(directory, showWarnings = FALSE)
  variants <- list(reference = character(), explicit_exports = c("-fvisibility=default",
    "-Wl,--export-dynamic"), semantic_interposition = "-fsemantic-interposition",
    no_memory_layout = "-qopt-mem-layout-trans=0",
    llvm_linker = c("-fuse-ld=lld",
      "-B/opt/intel/oneapi/compiler/latest/bin/compiler"),
    no_lto_diagnostic = "-fno-lto")
  results <- list()
  for (name in names(variants)) {
    flags <- variants[[name]]
    log <- file.path(directory, paste0(name, ".log"))
    arguments <- c("-f", shQuote(profile), "shared_probe",
      shQuote(paste0("CFLAGS=", settings$CFLAGS, " ", paste(flags, collapse = " "))),
      shQuote(paste0("LDFLAGS=", settings$LDFLAGS, " ", paste(flags, collapse = " "))))
    status <- suppressWarnings(system2("make", arguments, stdout = log, stderr = log))
    lines <- readLines(log, warn = FALSE)
    results[[name]] <- list(exit_status = as.integer(status),
      diagnostic_only = name != "reference",
      flags = flags, tail = tail(lines, 12L))
    cat("Shared export variant ", name, ": exit ", status, "\n", sep = "")
    cat(tail(lines, 12L), sep = "\n")
    if (name == "reference" && status == 0L) break
  }
  jsonlite::write_json(results, "/opt/tidyonnx/shared-export-probe.json",
    auto_unbox = TRUE, pretty = TRUE)
  cat("Shared export diagnostic summary\n")
  cat(jsonlite::toJSON(results, auto_unbox = TRUE, pretty = TRUE), "\n")
  identical(results$reference$exit_status, 0L)
}
