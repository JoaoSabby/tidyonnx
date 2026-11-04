# R entry points delegate to Docker launchers and never execute package tests on the host.
onnx_internal_launch_fedora <- function() {
  if (.Platform$OS.type == "windows") {
    command <- Sys.which("pwsh")
    if (!nzchar(command)) command <- Sys.which("powershell")
    if (!nzchar(command)) stop("PowerShell is required to launch the Fedora Docker tests.")
    arguments <- c("-NoProfile", "-File", shQuote("tools/run_fedora_tests.ps1"))
  } else {
    command <- Sys.which("sh")
    if (!nzchar(command)) stop("A POSIX shell is required to launch the Fedora Docker tests.")
    arguments <- shQuote("tools/run_fedora_tests.sh")
  }
  status <- system2(command, arguments)
  if (status != 0L) quit(status = status)
}
onnx_internal_launch_fedora()
