#' @title Register namespaced S7 interoperability methods
#' @description
#' S7 method integration is registered after the package namespace is loaded.
#' @param libname The package installation library, supplied by R.
#' @param pkgname The package name, supplied by R.
#' @return No user-facing value. Registration is performed for its side effect.
#' @seealso [methods_register()]
#' @references <https://rconsortium.github.io/S7/>
#' @keywords internal
.onLoad <- function(libname, pkgname){
  methods_register()
}
