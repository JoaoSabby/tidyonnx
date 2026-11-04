# Select only the pinned CPU assets; unsupported hosts have no fallback release.
onnx_internal_runtime_asset <- function(os = Sys.info()[["sysname"]],
    arch = R.version$arch, manifest = "inst/install/runtime_manifest.csv") {
  arch <- tolower(arch)
  arch <- switch(arch, x86_64 = "x64", amd64 = "x64", aarch64 = "arm64", arch)
  platform <- switch(os, Windows = "win", Linux = "linux", Darwin = "osx",
    stop("Unsupported ONNX Runtime operating system: ", os, call. = FALSE))
  key <- paste(platform, arch, sep = "-")
  manifest <- utils::read.csv(manifest, stringsAsFactors = FALSE)
  selected <- manifest[manifest$platform == key, , drop = FALSE]
  if (nrow(selected) != 1L) {
    stop("ONNX Runtime v1.31.1 has no supported CPU asset for ", key, ".",
      call. = FALSE)
  }
  selected
}

# Check member names before extraction, including drive-qualified and parent paths.
onnx_internal_archive_paths <- function(paths, root) {
  normalized <- gsub("\\", "/", paths, fixed = TRUE)
  if (!length(paths) || anyNA(paths) || any(grepl("^/|:|(^|/)\\.\\.(/|$)", normalized)) ||
      any(!startsWith(normalized, paste0(root, "/")) & normalized != root)) {
    stop("Unsafe runtime archive path or unexpected archive layout.", call. = FALSE)
  }
  invisible(paths)
}

# A verified official archive supplies matching C headers, private libraries and notices.
onnx_internal_install_runtime <- function() {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("Install the R dependency digest before installing tidyonnx.", call. = FALSE)
  }
  asset <- onnx_internal_runtime_asset()
  archive <- tempfile(fileext = if (endsWith(asset$asset, ".zip")) ".zip" else ".tgz")
  staging <- tempfile("tidyonnx-runtime-")
  dir.create(staging)
  on.exit(unlink(c(archive, staging), recursive = TRUE), add = TRUE)
  tryCatch({
    status <- utils::download.file(asset$url, archive, mode = "wb", quiet = FALSE,
      method = "libcurl")
    if (status != 0L) stop("HTTP transfer failed.")
  }, error = function(error) {
    stop("Cannot download ONNX Runtime v1.31.1 from the official release: ",
      conditionMessage(error), call. = FALSE)
  })
  actual <- onnx_internal_verify_archive(archive, asset$sha256)
  root <- sub("\\.(zip|tgz)$", "", asset$asset)
  zipped <- endsWith(archive, ".zip")
  paths <- if (zipped) utils::unzip(archive, list = TRUE)$Name else
    utils::untar(archive, list = TRUE)
  onnx_internal_archive_paths(paths, root)
  # The digest authorizes the archive; member checks also guard layout and traversal.
  if (zipped) utils::unzip(archive, exdir = staging) else
    utils::untar(archive, exdir = staging)
  extracted <- file.path(staging, root)
  resolved <- normalizePath(list.files(extracted, recursive = TRUE, full.names = TRUE),
    winslash = "/", mustWork = TRUE)
  prefix <- paste0(normalizePath(staging, winslash = "/", mustWork = TRUE), "/")
  if (any(!startsWith(resolved, prefix))) {
    stop("Runtime archive contains a link outside its extraction directory.", call. = FALSE)
  }
  private <- "inst/ort"
  headers <- "src/ort_include"
  dir.create(private, recursive = TRUE, showWarnings = FALSE)
  dir.create(headers, recursive = TRUE, showWarnings = FALSE)
  header_files <- file.path(extracted, "include", c("onnxruntime_c_api.h",
    "onnxruntime_ep_c_api.h", "onnxruntime_error_code.h"))
  libraries <- list.files(file.path(extracted, "lib"),
    pattern = "\\.(dll|dylib|so(\\.[0-9.]+)?)$", full.names = TRUE)
  required <- file.path(extracted, c("LICENSE", "ThirdPartyNotices.txt", "VERSION_NUMBER"))
  if (!length(libraries) || !all(file.exists(c(header_files, required)))) {
    stop("The official runtime archive is missing required C assets or notices.",
      call. = FALSE)
  }
  if (trimws(readLines(required[3L], warn = FALSE)[1L]) != "1.31.1") {
    stop("Unexpected ONNX Runtime archive version.", call. = FALSE)
  }
  if (!all(file.copy(header_files, headers, overwrite = TRUE)) ||
      !all(file.copy(c(libraries, required), private, overwrite = TRUE))) {
    stop("Cannot install the private ONNX Runtime files; check permissions.", call. = FALSE)
  }
  # Normalize copied headers without modifying the archived upstream source files.
  for (header in file.path(headers, basename(header_files))) {
    writeBin(charToRaw(paste0(paste(readLines(header, warn = FALSE),
      collapse = "\n"), "\n")), header)
  }
  asset$library_sha256 <- digest::digest(file = file.path(private,
    if (Sys.info()[["sysname"]] == "Windows") "onnxruntime.dll" else
      if (Sys.info()[["sysname"]] == "Darwin") "libonnxruntime.1.31.1.dylib" else
        "libonnxruntime.so.1.31.1"), algo = "sha256", serialize = FALSE)
  utils::write.csv(asset, file.path(private, "runtime.csv"), row.names = FALSE)
  onnx_internal_configure_flags()
  message("Installed private ONNX Runtime v1.31.1; archive SHA-256: ", actual)
}

# A mismatched digest prevents every extraction and native installation side effect.
onnx_internal_verify_archive <- function(archive, expected) {
  actual <- digest::digest(file = archive, algo = "sha256", serialize = FALSE)
  if (!identical(actual, expected)) {
    stop("ONNX Runtime archive SHA-256 mismatch; extraction refused.", call. = FALSE)
  }
  actual
}

# Portable suffix rules preserve configured R flags while selecting a final optimization.
onnx_internal_configure_flags <- function() {
  flags <- Sys.getenv("TIDYONNX_OPT_FLAGS", "-O3")
  if (!flags %in% c("", "-O0", "-O1", "-O2", "-O3", "-Os", "-Og")) {
    stop("TIDYONNX_OPT_FLAGS must be empty or a supported optimization level.", call. = FALSE)
  }
  template <- readLines("src/Makevars.in", warn = FALSE)
  template <- gsub("@OPT_FLAGS@", flags, template, fixed = TRUE)
  system <- Sys.info()[["sysname"]]
  template <- gsub("@DYNAMIC_LIBS@", if (system == "Linux") "-ldl" else "",
    template, fixed = TRUE)
  destination <- if (system == "Windows") "src/Makevars.win" else "src/Makevars"
  writeBin(charToRaw(paste0(paste(template, collapse = "\n"), "\n")), destination)
}
