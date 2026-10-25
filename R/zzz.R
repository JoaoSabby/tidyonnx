# Register S7 integration only after the namespace and its S3 methods are available.
.onLoad <- function(libname, pkgname) {
  S7::methods_register()
}
