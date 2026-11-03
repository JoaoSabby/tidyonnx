# Audit executable source policy independently of the installed package and test suite.
arguments <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(arguments)) arguments[[1L]] else ".", mustWork = TRUE)
paths <- list.files(root, recursive = TRUE, all.files = TRUE, full.names = TRUE)
paths <- paths[!grepl("[/\\\\]\\.git[/\\\\]", paths)]
source_files <- paths[grepl("\\.(R|c|cpp|h|yml|yaml)$", paths)]
runtime_files <- paths[grepl("\\.(py|pyc|pyo|pyw|ipynb)$", paths, ignore.case = TRUE)]
stopifnot("Forbidden runtime source files" = !length(runtime_files))

# Dependency and execution checks distinguish audit text from runtime use.
description <- read.dcf(file.path(root, "DESCRIPTION"))
dependencies <- paste(description[, intersect(colnames(description),
  c("Depends", "Imports", "Suggests", "LinkingTo", "SystemRequirements"))], collapse = " ")
stopifnot("Forbidden runtime dependency" = !grepl(
  "reticulate|rPython|rpy2|conda|virtualenv", dependencies, ignore.case = TRUE))
# Parse R syntax so a comment mentioning a loop cannot be mistaken for executable code.
r_files <- source_files[grepl("\\.R$", source_files)]
invisible(lapply(r_files, function(file) {
  code <- parse(file, keep.source = TRUE)
  if (any(utils::getParseData(code)$token == "FOR")) stop("Forbidden R loop in ", file)
  text <- paste(readLines(file, warn = FALSE), collapse = "\n")
  if (!grepl("(?m)^\\s*#", text, perl = TRUE)) stop("Uncommented R script: ", file)
}))
execution_pattern <- paste0("(reticulate|rPython|rpy2)[[:space:]]*::|",
  "(system2?|shell)[[:space:]]*\\([^\\n]*(python|conda)|setup-python")
invisible(lapply(source_files[!grepl("check-policy\\.R$", source_files)], function(file) {
  if (any(grepl(execution_pattern, readLines(file, warn = FALSE), ignore.case = TRUE))) {
    stop("Forbidden runtime bridge in ", file)
  }
}))
cat("Native-only policy: PASS; no R for loops; commented R scripts checked (",
  length(source_files), " source files).\n", sep = "")
