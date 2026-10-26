# Regenerate native bindings and reference pages from canonical source headers.
library(cpp11)
library(roxygen2)
library(stringr)

bindingFile <- file.path("R", "cpp11.R")
documentationLines <- readLines(file.path("tools", "native-docs.txt"), warn = FALSE)
functionLines <- grep("^cpp_[a-z_]+$", documentationLines)
cpp_register(".")
bindingText <- str_c(readLines(bindingFile, warn = FALSE), collapse = "\n")
for(blockIndex in seq_along(functionLines)){
  startIndex <- functionLines[blockIndex]
  endIndex <- if(blockIndex < length(functionLines)){
    functionLines[blockIndex + 1L] - 2L
  } else length(documentationLines)
  functionName <- documentationLines[startIndex]
  documentation <- str_c(documentationLines[seq.int(startIndex + 1L, endIndex)],
                         collapse = "\n")
  bindingText <- sub(
    str_c(functionName, " <- function"),
    str_c(documentation, "\n", functionName, " <- function"),
    bindingText, fixed = TRUE
  )
}
bindingText <- gsub(") {", "){", bindingText, fixed = TRUE)
writeLines(bindingText, bindingFile, useBytes = TRUE)
roxygenise(".", load_code = load_source)
referenceFiles <- list.files("man", pattern = "[.]Rd$", full.names = TRUE)
for(referenceFile in referenceFiles){
  referenceLines <- readLines(referenceFile, warn = FALSE, encoding = "UTF-8")
  writeLines(sub("[[:blank:]]+$", "", referenceLines), referenceFile, useBytes = TRUE)
}
