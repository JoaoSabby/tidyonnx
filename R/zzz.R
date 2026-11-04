# Runtime loading is deferred so staged installation can move an unlocked directory.
onnx_internal_runtime_state <- new.env(parent = emptyenv())

# Verify the installed binary without locking a Windows staged-installation directory.
.onLoad <- function(libname, pkgname) {
  private <- system.file("ort", package = pkgname, lib.loc = libname)
  manifest <- file.path(private, "runtime.csv")
  if (!file.exists(manifest)) stop("Private ONNX Runtime installation is missing.")
  runtime <- utils::read.csv(manifest, stringsAsFactors = FALSE)
  library <- file.path(private, switch(Sys.info()[["sysname"]],
    Windows = "onnxruntime.dll", Darwin = "libonnxruntime.1.31.1.dylib",
    Linux = "libonnxruntime.so.1.31.1", stop("Unsupported runtime platform.")))
  if (!file.exists(library) || !identical(
      digest::digest(file = library, algo = "sha256", serialize = FALSE),
      runtime$library_sha256)) {
    stop("Private ONNX Runtime binary is missing or its SHA-256 changed.")
  }
  onnx_internal_runtime_state$path <- normalizePath(library, winslash = "/", mustWork = TRUE)
  onnx_internal_runtime_state$initialized <- FALSE
  S7::methods_register()
}

# Session objects retain the runtime until their own native finalizers complete.
.onUnload <- function(libpath) {
  onnx_internal_release_runtime()
}
