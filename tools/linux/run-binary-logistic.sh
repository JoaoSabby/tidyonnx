#!/usr/bin/env bash
# Keep stage boundaries and operating-system evidence visible in the CI artifact.
set -euo pipefail
mkdir -p /artifacts
cat /etc/os-release | tee /artifacts/os-release.txt
uname -a | tee /artifacts/kernel.txt
rpm -q fedora-release R-core gcc gcc-c++ | tee /artifacts/system-packages.txt
Rscript tools/check-policy.R
Rscript tools/linux/train-binary-logistic.R /artifacts
Rscript tools/linux/convert-binary-logistic.R /artifacts
Rscript tools/linux/predict-binary-logistic.R /artifacts
Rscript tools/linux/compare-binary-logistic.R /artifacts
# Run available package tests as additional coverage; optional workflow tests may skip.
Rscript -e 'library(tidyonnx); testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)'
find /artifacts -maxdepth 1 -type f ! -name SHA256SUMS ! -name execution.log \
  -exec sha256sum {} + > /artifacts/SHA256SUMS
