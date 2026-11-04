# Distribution R bootstraps the current CRAN release used for every test.
source("/opt/tidyonnx/latest_versions.R")
options(timeout = max(600, getOption("timeout")), repos = c(CRAN = "https://cloud.r-project.org"))
fedora <- onnx_internal_fedora_version()
expected_fedora <- onnx_internal_latest_fedora()
if (fedora != expected_fedora) {
  stop("The pulled Fedora tag is not the latest stable release; no fallback is permitted.")
}

# The immutable reference profile is evaluated by make for both R and package builds.
profile <- "/opt/tidyonnx/intel_tools.mk"
reference <- "/opt/tidyonnx/profile/Makevars.001"
expected_profile <- "998a06d9f8531fe4179b8bfe993f8b29529cd441d0e6073d48dbdfa7161c74a0"
profile_hash <- strsplit(system2("sha256sum", shQuote(reference), stdout = TRUE),
  " +")[[1L]][1L]
if (!identical(profile_hash, expected_profile)) stop("The reference profile hash differs.")
cpu <- paste(readLines("/proc/cpuinfo", warn = FALSE), collapse = "\n")
required <- c("avx2", "fma", "avx512f", "avx512dq", "avx512cd", "avx512bw", "avx512vl",
  "avx512_vnni")
missing <- required[!vapply(required, function(flag) grepl(paste0("\\b", flag, "\\b"), cpu),
  logical(1))]
if (length(missing)) stop("The runner lacks Cascade Lake features: ",
  paste(missing, collapse = ", "), ". No architecture fallback is permitted.")

# Compiler and optimization values come from the supplied profile, not copied flag lists.
onnx_internal_profile_value <- function(name) {
  value <- system2("make", c("--no-print-directory", "-s", "-f", shQuote(profile),
    paste0("print-", name)), stdout = TRUE)
  if (!is.null(attr(value, "status")) || length(value) != 1L || !nzchar(value)) {
    stop("Cannot evaluate the Intel profile variable: ", name)
  }
  value
}
variables <- c("CC", "CFLAGS", "CPP", "CPPFLAGS", "CXX", "CXXFLAGS", "CXX17",
  "CXX17STD", "CXX17FLAGS", "CXX20", "CXX20STD", "CXX20FLAGS", "CXX23", "CXX23STD",
  "CXX23FLAGS", "FC", "F77", "FFLAGS", "FCFLAGS", "LDFLAGS", "AR", "RANLIB", "NM",
  "BLAS_LIBS", "LAPACK_LIBS", "FLIBS")
settings <- setNames(lapply(variables, onnx_internal_profile_value), variables)
do.call(Sys.setenv, settings)
if (system2("make", c("-f", shQuote(profile), "cpu_probe")) != 0L) {
  stop("The Intel Cascade Lake execution probe failed.")
}
versions <- lapply(c("icx", "icpx", "ifx"), function(command) {
  result <- system2(command, "--version", stdout = TRUE)
  if (!is.null(attr(result, "status"))) stop("An Intel compiler cannot execute: ", command)
  result
})
names(versions) <- c("icx", "icpx", "ifx")
jsonlite::write_json(list(profile_sha256 = profile_hash, compilers = versions,
  evaluated_variables = settings, cpu_features_required = required),
  "/opt/tidyonnx/intel-environment.json", auto_unbox = TRUE, pretty = TRUE)

release <- onnx_internal_latest_r()
directory <- "/opt/tidyonnx/r-build"
dir.create(directory, recursive = TRUE, showWarnings = FALSE)
archive <- file.path(directory, release$archive)
status <- utils::download.file(paste0(release$directory, release$archive), archive,
  mode = "wb", method = "libcurl")
if (status != 0L) stop("The latest stable R source archive could not be downloaded.")
published <- onnx_internal_r_checksum(release)
sha256 <- strsplit(system2("sha256sum", shQuote(archive), stdout = TRUE), " +")[[1L]][1L]
if (!grepl("^[a-f0-9]{64}$", sha256) || !identical(sha256, published$sha256)) {
  stop("The R source SHA-256 differs from the official release announcement.")
}

members <- utils::untar(archive, list = TRUE)
prefix <- paste0("R-", release$version, "/")
if (!length(members) || any(grepl("^/|(^|/)\\.\\.(/|$)", members)) ||
    any(!startsWith(members, prefix) & members != sub("/$", "", prefix))) {
  stop("The R source archive has unsafe paths or an unexpected layout.")
}
utils::untar(archive, exdir = directory)
setwd(file.path(directory, paste0("R-", release$version)))
if (!identical(trimws(readLines("VERSION", n = 1L, warn = FALSE)), release$version)) {
  stop("The extracted R source version differs from the selected official release.")
}
status <- system2("sh", c("configure", "--prefix=/opt/R/latest", "--enable-R-shlib",
  "--with-x=no", shQuote(paste0("--with-blas=", settings$BLAS_LIBS)),
  "--with-lapack", "--enable-memory-profiling"))
if (status != 0L) stop("Configuration of the latest stable R release failed.")
jobs <- Sys.getenv("TIDYONNX_BUILD_JOBS", "2")
if (!grepl("^[1-9][0-9]*$", jobs)) stop("TIDYONNX_BUILD_JOBS must be a positive integer.")
if (system2("make", paste0("-j", jobs)) != 0L || system2("make", "install") != 0L) {
  stop("Compilation or installation of the latest stable R release failed.")
}
# The bootstrap R home must not override the freshly compiled R installation.
Sys.unsetenv(c("R_HOME", "R_ARCH", "R_SHARE_DIR", "R_INCLUDE_DIR", "R_DOC_DIR"))
actual <- system2("/opt/R/latest/bin/Rscript",
  c("--vanilla", "-e", shQuote("cat(as.character(getRversion()))")), stdout = TRUE)
if (!identical(actual, release$version)) {
  stop("The installed R release is inconsistent: expected ", release$version,
    "; received ", paste(actual, collapse = " "), ".")
}
jsonlite::write_json(list(fedora = fedora, r_version = actual,
  r_source_url = paste0(release$directory, release$archive),
  r_source_sha256 = sha256, r_checksum_announcement = published$announcement_url,
  built_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)),
  "/opt/tidyonnx/environment.json", auto_unbox = TRUE, pretty = TRUE)
writeLines(as.character(fedora), "/etc/tidyonnx-test-container")
writeLines(profile_hash, "/etc/tidyonnx-intel-profile")
