source("tools/docker/latest_versions.R")
onnx_internal_assert_fedora_container(check_latest = FALSE)
# Audit authored text separately from unchanged handoff references and upstream assets.
directories <- c("R", "src", "tests", "tools", "inst/install", ".github")
files <- unlist(lapply(directories, list.files, recursive = TRUE, full.names = TRUE,
  all.files = TRUE), use.names = FALSE)
files <- files[grepl("\\.(R|cpp|c|h|md|csv|yaml|ps1|sh)$", files)]
files <- files[!grepl("/(nanopb|proto_generated|ort_include)/", files)]
files <- unique(c(files, "DESCRIPTION", "NAMESPACE", "README.md", "ARCHITECTURE.md",
  "VALIDATION.md", "NEWS.md", "configure", "configure.win", "cleanup", "cleanup.win", "tools/docker/Dockerfile", "tools/docker/intel_profile.mk",
  "tools/docker/intel_tools.mk",
  "tools/docker/reference/Makevars.001", "tools/docker/oneapi.repo", ".dockerignore"))
excluded_word <- paste0("py", "thon")
for (file in files) {
  lines <- readLines(file, warn = FALSE)
  if (any(grepl(excluded_word, lines, ignore.case = TRUE, fixed = FALSE))) {
    stop("Excluded authored text in: ", file)
  }
  if (!grepl("\\.(R|cpp|c|h|ps1|sh)$", file)) next
  comments <- if (grepl("\\.(R|ps1|sh)$", file)) grepl("^\\s*#", lines) else
    grepl("^\\s*(//|/\\*|\\*)", lines)
  if (any(nchar(lines[comments], type = "chars") > 90L) ||
      any(grepl("[^\x01-\x7F]", lines[comments]))) {
    stop("Comment width or ASCII policy failed: ", file)
  }
}
archive <- Sys.getenv("TIDYONNX_SOURCE_ARCHIVE", paste0("tidyonnx_",
  read.dcf("DESCRIPTION")[1L, "Version"], ".tar.gz"))
members <- utils::untar(archive, list = TRUE)
if (any(grepl("\\.(o|dll|so|a|zip|tgz)$|/ort_include/|/inst/ort/", members))) {
  stop("Source archive contains generated headers or native binary artifacts.")
}
if (any(endsWith(tolower(members), paste0(".", "py")))) {
  stop("Source archive contains an excluded language source file.")
}
cat("Authored source text, comment ASCII/width and source archive gates passed.\n")
cat("Unchanged handoff references and downloaded upstream files were excluded explicitly.\n")
