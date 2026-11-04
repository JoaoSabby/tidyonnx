# This entry point owns all package validation inside the verified Fedora Docker image.
source("tools/docker/latest_versions.R")
onnx_internal_assert_fedora_container()
options(timeout = max(600, getOption("timeout")), repos = c(CRAN = "https://cloud.r-project.org"))
repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
evidence <- "/evidence"
if (!dir.exists(evidence) || file.access(evidence, 2L) != 0L) {
  stop("Bind a writable evidence directory at /evidence.")
}
file.copy("/opt/tidyonnx/environment.json", file.path(evidence, "image-environment.json"),
  overwrite = TRUE)
file.copy("/opt/tidyonnx/intel-environment.json",
  file.path(evidence, "intel-environment.json"), overwrite = TRUE)
file.copy("/opt/tidyonnx/profile/Makevars.001",
  file.path(evidence, "Makevars.001"), overwrite = TRUE)
file.copy("/opt/tidyonnx/intel_profile.mk",
  file.path(evidence, "intel_profile.mk"), overwrite = TRUE)
file.copy("/opt/tidyonnx/intel_tools.mk",
  file.path(evidence, "intel_tools.mk"), overwrite = TRUE)
file.copy("/proc/cpuinfo", file.path(evidence, "cpuinfo.txt"), overwrite = TRUE)
provenance <- list(fedora = onnx_internal_fedora_version(),
  r_version = as.character(getRversion()), runtime_version = "1.31.1",
  platform = R.version$platform, started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))
jsonlite::write_json(provenance, file.path(evidence, "run-environment.json"),
  auto_unbox = TRUE, pretty = TRUE)

# A command whitelist makes the excluded interpreter unavailable during install and tests.
onnx_internal_test_path <- function() {
  directory <- tempfile("test-bin-")
  dir.create(directory)
  commands <- c("R", "Rscript", "sh", "bash", "env", "make", "cmake", "gcc", "g++",
    "gfortran", "icx", "icpx", "ifx", "ccache", "llvm-ar", "llvm-nm", "llvm-ranlib",
    "cc", "c++", "ar", "as", "ld", "ranlib", "nm", "strip", "objdump",
    "readelf", "strings", "file", "pkg-config", "tar", "gzip", "bzip2", "xz", "unzip",
    "curl", "git", "sha256sum", "ldd", "getconf", "nproc", "uname", "which", "cat",
    "ls", "cp", "mv", "rm", "mkdir", "rmdir", "chmod", "touch", "ln", "install",
    "sleep", "date", "head", "tail", "wc", "cut", "paste", "sort", "uniq", "tr",
    "grep", "sed", "awk", "find", "xargs", "tee", "diff", "cmp", "patch", "true",
    "false", "basename", "dirname", "expr", "pwd", "printf", "df", "du", "stat",
    "readlink", "realpath", "id", "whoami", "ps", "kill", "nice", "hostname", "perl")
  paths <- Sys.which(commands)
  for (name in names(paths)[nzchar(paths)]) {
    if (!file.symlink(paths[[name]], file.path(directory, name))) {
      stop("Cannot construct the restricted test command PATH.")
    }
  }
  Sys.setenv(PATH = directory)
  if (nzchar(Sys.which(paste0("py", "thon"))) ||
      nzchar(Sys.which(paste0("py", "thon3")))) {
    stop("An excluded interpreter is present on the restricted test PATH.")
  }
  writeLines(c(paste("PATH", Sys.getenv("PATH")), "Excluded interpreter absent from PATH"),
    file.path(evidence, "restricted-path.txt"))
}
onnx_internal_test_path()
r <- file.path(R.home("bin"), "R")
rscript <- file.path(R.home("bin"), "Rscript")
library_path <- "/opt/tidyonnx/library"
dir.create(library_path, recursive = TRUE, showWarnings = FALSE)
phases <- list()

# Independent failures are retained while later feasible validation phases still run.
onnx_internal_phase <- function(name, expression, requires = character()) {
  dependencies <- vapply(requires, function(value) identical(phases[[value]]$status, "passed"),
    logical(1))
  if (!all(dependencies)) {
    phases[[name]] <<- list(status = "blocked", detail = "A prerequisite phase failed.")
    return(invisible(FALSE))
  }
  cat("Starting phase: ", name, "\n", sep = "")
  started <- proc.time()[["elapsed"]]
  result <- tryCatch({
    force(expression)
    list(status = "passed", detail = "")
  }, error = function(error) {
    list(status = "failed", detail = conditionMessage(error))
  })
  result$seconds <- proc.time()[["elapsed"]] - started
  phases[[name]] <<- result
  cat(name, ": ", result$status, " ", result$detail, "\n", sep = "")
  invisible(identical(result$status, "passed"))
}

# Subprocess output is retained even when a compiler, loader or test command fails.
onnx_internal_command <- function(command, arguments, name) {
  log <- file.path(evidence, name)
  status <- system2(command, arguments, stdout = log, stderr = log)
  if (!identical(as.integer(status), 0L)) {
    cat(tail(readLines(log, warn = FALSE), 30L), sep = "\n")
    stop("Command failed; see ", name, " (exit ", status, ").", call. = FALSE)
  }
  invisible(status)
}
description <- read.dcf("DESCRIPTION")
archive <- file.path(repo, paste0(description[1L, "Package"], "_",
  description[1L, "Version"], ".tar.gz"))

onnx_internal_phase("build", {
  onnx_internal_command(r, c("CMD", "build", "--no-build-vignettes", "--no-manual", "."),
    "build.log")
  file.copy(archive, file.path(evidence, basename(archive)), overwrite = TRUE)
  onnx_internal_command("sha256sum", shQuote(archive), "source-archive-sha256.txt")
})
onnx_internal_phase("install", {
  onnx_internal_command(r, c("CMD", "INSTALL", "--preclean", "--no-multiarch",
    paste0("--library=", shQuote(library_path)), "."), "install.log")
  .libPaths(c(library_path, .libPaths()))
  Sys.setenv(R_LIBS_USER = paste(.libPaths(), collapse = .Platform$path.sep))
  library(tidyonnx)
})
onnx_internal_phase("focused", {
  connection <- file(file.path(evidence, "focused.log"), open = "wt")
  sink(connection, split = TRUE)
  result <- tryCatch(testthat::test_dir(file.path(repo, "tests", "testthat"),
    reporter = "summary", stop_on_failure = FALSE), finally = {
      sink()
      close(connection)
    })
  saveRDS(result, file.path(evidence, "test-results.rds"))
  frame <- as.data.frame(result)
  utils::write.csv(frame[setdiff(names(frame), "result")],
    file.path(evidence, "test-results.csv"), row.names = FALSE)
  if (any(frame$failed > 0L | frame$error | frame$warning > 0L | frame$skipped)) {
    stop("Focused tests contain failures, errors, warnings or skips.")
  }
}, requires = "install")
onnx_internal_phase("independent", {
  executable <- file.path(evidence, "validate_runtime")
  onnx_internal_command("make", c("-f", shQuote("/opt/tidyonnx/intel_tools.mk"),
    "validator", paste0("SOURCE_DIR=", shQuote(repo)), paste0("VALIDATOR=", shQuote(executable))),
    "independent-build.log")
  runtime <- system.file("ort", "libonnxruntime.so.1.31.1", package = "tidyonnx")
  onnx_internal_command(rscript, c("--vanilla", shQuote("tools/validate_runtime.R"),
    shQuote(executable), shQuote(runtime), shQuote(file.path(evidence, "independent"))),
    "independent.log")
}, requires = "install")
onnx_internal_phase("fresh_session", {
  onnx_internal_command(rscript, c("--vanilla", shQuote("tools/validate_session.R"),
    shQuote(file.path(evidence, "independent", "scenario-1.onnx"))), "fresh-process.log")
}, requires = "independent")
onnx_internal_phase("benchmarks", {
  source("tools/docker/benchmark_fedora.R")
  onnx_internal_benchmark_fedora(evidence)
}, requires = "install")
onnx_internal_phase("native_dependencies", {
  runtime <- system.file("ort", "libonnxruntime.so.1.31.1", package = "tidyonnx")
  package <- getLoadedDLLs()[["tidyonnx"]][["path"]]
  provider <- system.file("ort", "libonnxruntime_providers_shared.so", package = "tidyonnx")
  if (nzchar(provider)) {
    onnx_internal_command("ldd", shQuote(provider), "provider-dependencies.txt")
  }
  onnx_internal_command("ldd", shQuote(runtime), "runtime-dependencies.txt")
  onnx_internal_command("ldd", shQuote(package), "package-dependencies.txt")
  dependencies <- unlist(lapply(file.path(evidence,
    c("runtime-dependencies.txt", "package-dependencies.txt",
      if (nzchar(provider)) "provider-dependencies.txt")), readLines, warn = FALSE))
  if (any(grepl(paste0("py", "thon"), dependencies, ignore.case = TRUE)) ||
      any(grepl("not found", dependencies, fixed = TRUE))) {
    stop("A native dependency is unavailable or violates the runtime contract.")
  }
  runtime_manifest <- system.file("ort", "runtime.csv", package = "tidyonnx")
  file.copy(runtime_manifest, file.path(evidence, "runtime.csv"), overwrite = TRUE)
}, requires = "install")
onnx_internal_phase("policy", {
  Sys.setenv(TIDYONNX_SOURCE_ARCHIVE = archive)
  onnx_internal_command(rscript, c("--vanilla", shQuote("tools/validate_policy.R")), "policy.log")
}, requires = "build")
onnx_internal_phase("package_check", {
  output <- tempfile("package-check-")
  dir.create(output)
  log <- file.path(evidence, "check-console.log")
  status <- system2(r, c("CMD", "check", "--no-manual", "--no-build-vignettes",
    paste0("--output=", shQuote(output)), shQuote(archive)), stdout = log, stderr = log)
  check <- file.path(output, paste0(description[1L, "Package"], ".Rcheck"))
  for (name in c("00check.log", "00install.out", "tests/testthat.Rout",
      "tests/testthat.Rout.fail")) {
    if (file.exists(file.path(check, name))) {
      file.copy(file.path(check, name), file.path(evidence, basename(name)), overwrite = TRUE)
    }
  }
  record <- file.path(check, "00check.log")
  clean <- file.exists(record) && any(grepl("^Status: OK", readLines(record, warn = FALSE)))
  if (status != 0L || !clean) {
    stop("R CMD check is not clean; inspect the retained warnings, notes or errors.")
  }
}, requires = "build")
utils::write.csv(as.data.frame(utils::installed.packages()),
  file.path(evidence, "installed-packages.csv"), row.names = FALSE)
onnx_internal_command("icx", "--version", "c-compiler-version.txt")
onnx_internal_command("icpx", "--version", "cxx-compiler-version.txt")
onnx_internal_command("ifx", "--version", "fortran-compiler-version.txt")
onnx_internal_command("ldd", shQuote(file.path(R.home("lib"), "libR.so")),
  "r-native-dependencies.txt")
onnx_internal_command("sha256sum", shQuote("/opt/tidyonnx/profile/Makevars.001"),
  "profile-sha256.txt")
configuration <- file.path(evidence, "test-configuration")
dir.create(configuration, showWarnings = FALSE)
file.copy("tools", configuration, recursive = TRUE)
file.copy(".github", configuration, recursive = TRUE)
file.copy(c(".dockerignore", ".Rbuildignore"), configuration)
writeLines(capture.output(sessionInfo()), file.path(evidence, "session-info.txt"))
jsonlite::write_json(phases, file.path(evidence, "phase-results.json"),
  auto_unbox = TRUE, pretty = TRUE)
if (any(vapply(phases, function(phase) !identical(phase$status, "passed"), logical(1)))) {
  quit(status = 1L)
}
cat("All Fedora container validation phases passed.\n")
