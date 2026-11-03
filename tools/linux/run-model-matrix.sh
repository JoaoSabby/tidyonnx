#!/usr/bin/env bash
# Compare the same persisted source references under GCC and real Intel compiler builds.
set -euo pipefail
mkdir -p /artifacts/model-matrix
cat /etc/os-release > /artifacts/model-matrix/os-release.txt
cat /proc/cpuinfo > /artifacts/model-matrix/cpu.txt
Rscript tools/check-policy.R
Rscript tools/linux/model-matrix.R /artifacts/model-matrix gcc
Rscript -e 'library(tidyonnx); testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)'

# Refuse to claim AVX-512 execution on a runner lacking its required CPU/OS flags.
grep -qw avx512f /proc/cpuinfo
grep -qw avx512bw /proc/cpuinfo
grep -qw avx512dq /proc/cpuinfo
grep -qw avx512vl /proc/cpuinfo
set +u
source /opt/intel/oneapi/compiler/latest/env/vars.sh
set -u
icx --version | tee /artifacts/model-matrix/intel-compiler.txt
icx -O3 -march=skylake-avx512 tools/linux/avx512-probe.c -o /tmp/avx512-probe
objdump -d /tmp/avx512-probe > /artifacts/model-matrix/avx512-probe-assembly.txt
grep -q zmm /artifacts/model-matrix/avx512-probe-assembly.txt
/tmp/avx512-probe | tee /artifacts/model-matrix/avx512-execution.txt

# Preserve source arithmetic while enabling aggressive architecture-specific optimization.
mkdir -p /opt/validation-libs/intel-precise /opt/validation-libs/intel-fast
cat > /tmp/Makevars.intel-precise <<'EOF'
CC = icx
CC17 = icx -std=gnu17
CXX = icpx
CXX17 = icpx
CXX17STD = -std=c++17
# Keep both C standards and C++ independent of R's command-line CFLAGS mapping.
TIDYONNX_INTEL_FLAGS = -O3 -march=skylake-avx512 -qopt-zmm-usage=high -fp-model=strict -fno-builtin-expf -ffp-contract=off
CFLAGS = $(TIDYONNX_INTEL_FLAGS)
C17FLAGS = $(TIDYONNX_INTEL_FLAGS)
CXX17FLAGS = $(TIDYONNX_INTEL_FLAGS)
SHLIB_OPENMP_CFLAGS = -qopenmp
LDFLAGS = -Wl,-rpath,/opt/intel/oneapi/compiler/latest/lib
EOF
R_MAKEVARS_USER=/tmp/Makevars.intel-precise R CMD INSTALL --preclean --no-multiarch \
  --library=/opt/validation-libs/intel-precise . 2>&1 | tee /artifacts/model-matrix/intel-precise-build.log
grep -q 'icx.*-c ' /artifacts/model-matrix/intel-precise-build.log
grep -q 'icpx.*-c ' /artifacts/model-matrix/intel-precise-build.log
objdump -d /opt/validation-libs/intel-precise/tidyonnx/libs/tidyonnx.so \
  > /artifacts/model-matrix/intel-precise-assembly.txt
R_LIBS=/opt/validation-libs/intel-precise Rscript tools/linux/model-matrix.R \
  /artifacts/model-matrix intel-precise
R_LIBS=/opt/validation-libs/intel-precise Rscript -e 'library(tidyonnx); testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)'

# Treat fast-math as an experiment: failures are retained and the configuration is rejected.
sed 's/-fp-model=strict -fno-builtin-expf -ffp-contract=off/-fp-model=fast=2 -ffast-math/g' \
  /tmp/Makevars.intel-precise > /tmp/Makevars.intel-fast
R_MAKEVARS_USER=/tmp/Makevars.intel-fast R CMD INSTALL --preclean --no-multiarch \
  --library=/opt/validation-libs/intel-fast . 2>&1 | tee /artifacts/model-matrix/intel-fast-build.log
if R_LIBS=/opt/validation-libs/intel-fast Rscript tools/linux/model-matrix.R \
  /artifacts/model-matrix intel-fast; then
  echo 'accepted by this fixture' > /artifacts/model-matrix/intel-fast-status.txt
else
  echo 'rejected: prediction equivalence or input semantics failed' \
    > /artifacts/model-matrix/intel-fast-status.txt
fi
