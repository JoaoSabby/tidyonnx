# Check repository text and documentation coverage before package validation.
sourceFiles <- list.files(
  ".", recursive = TRUE, all.files = TRUE, full.names = TRUE, no.. = TRUE
)
sourceFiles <- sourceFiles[!grepl("(^|/)[.]git/|(^|/)[^/]*[.]Rcheck/|[.](o|so|dll|a|tar[.]gz|zip)$", sourceFiles)]
sourceFiles <- sourceFiles[!dir.exists(sourceFiles)]
if(any(grepl("[.](py|pyc|pyo|ipynb)$", sourceFiles, ignore.case = TRUE))){
  stop("A prohibited source format was found.", call. = FALSE)
}
forbiddenTerm <- intToUtf8(c(112L, 121L, 116L, 104L, 111L, 110L))
for(file in sourceFiles){
  fileText <- readLines(file, warn = FALSE, encoding = "UTF-8")
  if(any(grepl(forbiddenTerm, fileText, ignore.case = TRUE))){
    stop("A prohibited dependency reference was found in ", file, call. = FALSE)
  }
}
rFiles <- list.files("R", pattern = "[.]R$", full.names = TRUE)
functionCount <- 0L
for(file in rFiles){
  sourceLines <- readLines(file, warn = FALSE, encoding = "UTF-8")
  definitionLines <- grep("^[A-Za-z.][A-Za-z0-9_.]* <- function", sourceLines)
  functionCount <- functionCount + length(definitionLines)
  for(lineIndex in definitionLines){
    if(lineIndex == 1L || !startsWith(sourceLines[lineIndex - 1L], "#'")){
      stop("Missing function documentation in ", file, ":", lineIndex, call. = FALSE)
    }
  }
}
cat("Source checks passed; documented named R functions:", functionCount, "\n")
