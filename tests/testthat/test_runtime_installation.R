test_that("the manifest pins all CPU platforms and rejects unsupported architectures", {
  installer <- new.env(parent = globalenv())
  sys.source(system.file("install", "onnx_internal_install_runtime.R", package = "tidyonnx"),
    envir = installer)
  manifest_path <- system.file("install", "runtime_manifest.csv", package = "tidyonnx")
  # Use the installed manifest so this test also runs in an R CMD check source archive.
  asset <- function(os, arch) installer$onnx_internal_runtime_asset(os, arch, manifest_path)
  expect_identical(asset("Windows", "x86_64")$platform, "win-x64")
  expect_identical(asset("Windows", "aarch64")$platform, "win-arm64")
  expect_identical(asset("Linux", "aarch64")$platform, "linux-arm64")
  expect_identical(asset("Darwin", "arm64")$platform, "osx-arm64")
  expect_error(asset("Darwin", "x86_64"), "no supported CPU asset")
  expect_error(asset("Linux", "i386"), "no supported CPU asset")
  expect_error(asset("Other", "x64"), "Unsupported")
  manifest <- read.csv(manifest_path)
  expect_true(all(grepl("^https://github.com/microsoft/onnxruntime/releases/download/v1.31.1/",
    manifest$url, fixed = FALSE)))
  expect_true(all(nchar(manifest$sha256) == 64L))
  check <- installer$onnx_internal_archive_paths
  expect_invisible(check(c("root/include/header.h", "root/lib/library.dll"), "root"))
  for (paths in list("../bad", "/root/bad", "C:/root/bad", "root/../bad",
      "root\\..\\bad", "other/file")) {
    expect_error(check(paths, "root"), "Unsafe")
  }
  file <- tempfile()
  on.exit(unlink(file), add = TRUE)
  writeBin(as.raw(1:10), file)
  expect_error(installer$onnx_internal_verify_archive(file, strrep("0", 64)),
    "SHA-256 mismatch; extraction refused")
})

test_that("the installed private runtime carries matching version and digest diagnostics", {
  runtime <- read.csv(system.file("ort", "runtime.csv", package = "tidyonnx"))
  expect_match(runtime$asset, "1.31.1")
  expect_true(file.exists(system.file("ort", "LICENSE", package = "tidyonnx")))
  expect_true(file.exists(system.file("ort", "ThirdPartyNotices.txt", package = "tidyonnx")))
  expect_identical(onnx_inspect(onnx_internal_fixture_model())$engine$version, "1.31.1")
})
