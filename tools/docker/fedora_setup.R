# Distribution R bootstraps the current CRAN release used for every test.
source("/opt/tidyonnx/latest_versions.R")
options(timeout = max(600, getOption("timeout")), repos = c(CRAN = "https://cloud.r-project.org"))
fedora <- onnx_internal_fedora_version()
expected_fedora <- onnx_internal_latest_fedora()
if (fedora != expected_fedora) {
  stop("The pulled Fedora tag is not the latest stable release; no fallback is permitted.")
}
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
  "--with-x=no", "--with-blas", "--with-lapack", "--enable-memory-profiling"))
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
