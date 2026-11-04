# Unavailable official metadata must never select an older release.
onnx_internal_download_text <- function(address) {
  tryCatch({
    connection <- url(address, open = "rb", method = "libcurl")
    on.exit(close(connection), add = TRUE)
    readLines(connection, warn = FALSE)
  }, error = function(error) {
    stop("Cannot read official release metadata at ", address, ": ",
      conditionMessage(error), call. = FALSE)
  })
}

# Stable source filenames exclude release candidates and development snapshots.
onnx_internal_latest_r <- function() {
  root <- "https://cran.r-project.org/src/base/"
  page <- paste(onnx_internal_download_text(root), collapse = "\n")
  links <- regmatches(page, gregexpr('href="R-[0-9]+/"', page))[[1L]]
  if (!length(links)) stop("CRAN lists no stable R source series.", call. = FALSE)
  major <- max(as.integer(gsub("[^0-9]", "", links)))
  directory <- paste0(root, "R-", major, "/")
  page <- paste(onnx_internal_download_text(directory), collapse = "\n")
  archives <- unique(regmatches(page,
    gregexpr("R-[0-9]+\\.[0-9]+\\.[0-9]+\\.tar\\.gz", page))[[1L]])
  if (!length(archives)) stop("CRAN lists no stable R source release.", call. = FALSE)
  versions <- sub("^R-|\\.tar\\.gz$", "", archives)
  versions <- sub("\\.tar\\.gz$", "", versions)
  latest <- as.character(sort(package_version(versions), decreasing = TRUE)[1L])
  list(version = latest, archive = paste0("R-", latest, ".tar.gz"), directory = directory)
}

# Fedora's official metadata identifies stable numeric versions without assuming a tag.
onnx_internal_latest_fedora <- function() {
  document <- paste(onnx_internal_download_text("https://fedoraproject.org/releases.json"),
    collapse = "\n")
  releases <- jsonlite::fromJSON(document)
  versions <- as.character(releases$version)
  versions <- versions[grepl("^[0-9]+$", versions)]
  if (!length(versions)) stop("Fedora lists no stable release.", call. = FALSE)
  max(as.integer(versions))
}

# Explicit OS metadata prevents an Ubuntu or Windows host from becoming a test fallback.
onnx_internal_fedora_version <- function() {
  if (!identical(Sys.info()[["sysname"]], "Linux") || !file.exists("/etc/os-release")) {
    stop("Package validation requires the Fedora Docker image.", call. = FALSE)
  }
  release <- readLines("/etc/os-release", warn = FALSE)
  id <- gsub('"', "", sub("^ID=", "", grep("^ID=", release, value = TRUE)))
  version <- gsub('"', "", sub("^VERSION_ID=", "",
    grep("^VERSION_ID=", release, value = TRUE)))
  if (!identical(id, "fedora") || length(version) != 1L ||
      !grepl("^[0-9]+$", version)) {
    stop("Package validation requires a stable Fedora Linux release.", call. = FALSE)
  }
  as.integer(version)
}

# Each run checks current releases, so a stale image must be rebuilt before testing.
onnx_internal_assert_fedora_container <- function(check_latest = TRUE) {
  fedora <- onnx_internal_fedora_version()
  if (Sys.getenv("TIDYONNX_FEDORA_CONTAINER") != "1" ||
      !file.exists("/etc/tidyonnx-test-container")) {
    stop("Use tools/run_fedora_tests.sh or tools/run_fedora_tests.ps1.", call. = FALSE)
  }
  expected_profile <- "998a06d9f8531fe4179b8bfe993f8b29529cd441d0e6073d48dbdfa7161c74a0"
  marker <- "/etc/tidyonnx-intel-profile"
  if (!file.exists(marker) ||
      !identical(readLines(marker, warn = FALSE), expected_profile) ||
      Sys.getenv("R_MAKEVARS_USER") != "/opt/tidyonnx/intel_profile.mk") {
    stop("Validation requires the Intel reference image and supplied Makevars profile.",
      call. = FALSE)
  }
  if (check_latest) {
    latest_fedora <- onnx_internal_latest_fedora()
    latest_r <- onnx_internal_latest_r()$version
    if (fedora != latest_fedora ||
        !identical(as.character(getRversion()), latest_r)) {
      stop("The image is stale; rebuild with the latest stable Fedora and R.",
        call. = FALSE)
    }
  }
  invisible(fedora)
}


# The official release announcement supplies an independent required SHA-256 value.
onnx_internal_r_checksum <- function(release) {
  root <- "https://stat.ethz.ch/pipermail/r-announce/"
  index <- paste(onnx_internal_download_text(root), collapse = "\n")
  entries <- regmatches(index, gregexpr("[0-9]{4}/thread\\.html", index))[[1L]]
  if (!length(entries)) stop("Official R release announcements are unavailable.")
  years <- sort(unique(as.integer(sub("/.*", "", entries))), decreasing = TRUE)
  major <- strsplit(release$version, ".", fixed = TRUE)[[1L]][1L]
  filename <- paste0("R-", major, "/", release$archive)
  filename <- gsub(".", "[.]", filename, fixed = TRUE)
  pattern <- paste0("[[:xdigit:]]{64}[[:space:]]+", filename, "([[:space:]<]|$)")
  for (year in head(years, 2L)) {
    thread <- onnx_internal_download_text(paste0(root, year, "/thread.html"))
    candidates <- thread[grepl(release$version, thread, fixed = TRUE) &
      grepl("released", thread, ignore.case = TRUE)]
    messages <- unique(unlist(regmatches(candidates,
      gregexpr("[0-9]+\\.html", candidates)), use.names = FALSE))
    for (message in messages) {
      address <- paste0(root, year, "/", message)
      document <- paste(onnx_internal_download_text(address), collapse = "\n")
      hashes <- unique(tolower(substr(regmatches(document,
        gregexpr(pattern, document, perl = TRUE))[[1L]], 1L, 64L)))
      if (length(hashes) == 1L) return(list(sha256 = hashes, announcement_url = address))
    }
  }
  stop("No unique official SHA-256 for the latest R release; compilation refused.")
}
