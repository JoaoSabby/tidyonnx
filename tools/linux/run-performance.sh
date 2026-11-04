#!/usr/bin/env bash
# Compare a conventional GCC build against the exact user-supplied Intel Makevars file.
set -euo pipefail
makevars="${1:-../Makevars.001}"
output="${2:-/artifacts/performance}"
test -f "$makevars" || { echo "Required Makevars file not found: $makevars" >&2; exit 2; }
makevars="$(realpath "$makevars")"
mkdir -p "$output" /opt/performance-libs/gcc /opt/performance-libs/intel-makevars001
output="$(realpath "$output")"
test ! -f "$output/fixture.rds" || { echo "Use a fresh performance output directory." >&2; exit 2; }
export CCACHE_DISABLE=1
export MAKEFLAGS=-j2
cp "$makevars" "$output/Makevars.001"
sha256sum "$makevars" > "$output/Makevars.001.sha256"
cat /etc/os-release > "$output/os-release.txt"
cat /proc/cpuinfo > "$output/cpu.txt"
printf 'profile,seconds\n' > "$output/build-seconds.csv"
gcc --version > "$output/gcc-version.txt"
printf '%s\n' "${SOURCE_REVISION:-unknown}" > "$output/source-revision.txt"
Rscript tools/check-policy.R

# Use O2 and OpenMP without architecture-specific targeting as the conventional baseline.
cat > /tmp/Makevars.performance-gcc <<'EOF'
# Match the R-selected C17 and C++17 standards while keeping a generic GCC target.
CC = gcc
CC17 = gcc -std=gnu17
CXX = g++
CXX17 = g++
CXX17STD = -std=c++17
CFLAGS = -O2
C17FLAGS = -O2
CXX17FLAGS = -O2
SHLIB_OPENMP_CFLAGS = -fopenmp
LDFLAGS =
# The same MAKEFLAGS environment controls both compiler builds.
EOF
cp /tmp/Makevars.performance-gcc "$output/Makevars.gcc"
start="$(date +%s%N)"
R_MAKEVARS_USER=/tmp/Makevars.performance-gcc R CMD INSTALL --preclean --no-multiarch \
  --library=/opt/performance-libs/gcc . 2>&1 | tee "$output/gcc-build.log"
elapsed="$(($(date +%s%N) - start))"
printf 'gcc,%s.%09d\n' "$((elapsed / 1000000000))" "$((elapsed % 1000000000))" >> "$output/build-seconds.csv"

# Initialize Intel without modifying, filtering, or silently replacing the supplied flags.
set +u
source /opt/intel/oneapi/compiler/latest/env/vars.sh
set -u
icx --version > "$output/intel-version.txt"
# Adapt installation paths through supported environment inputs, preserving file bytes.
export ONEAPI_ROOT=/opt/intel/oneapi
export COMPILER_BIN="$ONEAPI_ROOT/compiler/latest/bin"
export COMPILER_LIB="$ONEAPI_ROOT/compiler/latest/lib"
export MKL_ROOT="$ONEAPI_ROOT/mkl/latest"
export MKL_LIB="$MKL_ROOT/lib"
export TBB_LIB="$ONEAPI_ROOT/tbb/latest/lib"
# R selects C17 for this package; reuse every optimization flag under that standard.
makevars_wrapper="$output/Makevars.intel-r"
printf 'include %s\n' "$makevars" > "$makevars_wrapper"
cat >> "$makevars_wrapper" <<'EOF'
# Map the original Intel configuration to the R-requested C17 compiler macros.
CC17 = $(CCACHE_BIN) $(COMPILER_BIN)/icx -std=gnu17
C17FLAGS = -std=gnu17 $(COMMON_C_FLAGS) $(OPT_WARNINGS_C) $(OPT_MACROS_C)
EOF
export LD_LIBRARY_PATH="/opt/intel/oneapi/compiler/latest/lib:${LD_LIBRARY_PATH:-}"
make --no-print-directory -f "$makevars_wrapper" -f tools/linux/report-makevars.mk report > "$output/intel-effective-makevars.txt"
make --no-print-directory -f /tmp/Makevars.performance-gcc -f tools/linux/report-makevars.mk report > "$output/gcc-effective-makevars.txt"
start="$(date +%s%N)"
R_MAKEVARS_USER="$makevars_wrapper" R CMD INSTALL --preclean --no-multiarch \
  --library=/opt/performance-libs/intel-makevars001 . 2>&1 | tee "$output/intel-build.log"
elapsed="$(($(date +%s%N) - start))"
printf 'intel-makevars001,%s.%09d\n' "$((elapsed / 1000000000))" "$((elapsed % 1000000000))" >> "$output/build-seconds.csv"
grep -q 'icx.*-c ' "$output/intel-build.log"
grep -q 'icpx.*-c ' "$output/intel-build.log"

# Fit once under GCC and preserve every reference before either profile is measured.
R_LIBS=/opt/performance-libs/gcc Rscript tools/linux/prepare-performance.R "$output"

# Fingerprint fixtures before timing so later phases cannot silently replace references.
sha256sum "$output/"*.ubj "$output/"*.onnx "$output/"*-reference.rds \
  "$output/inputs.rds" "$output/fixture.rds" > "$output/fixture-sha256.txt"

# Alternate profile order across independent process blocks to reduce temporal bias.
for block in 1 2 3; do
  if (( block % 2 )); then profiles=(gcc intel-makevars001); else profiles=(intel-makevars001 gcc); fi
  for profile in "${profiles[@]}"; do
    R_LIBS="/opt/performance-libs/$profile" \
      Rscript tools/linux/measure-performance.R "$output" "$profile" "$block"
  done
done
sha256sum -c "$output/fixture-sha256.txt"
Rscript tools/linux/compare-performance.R "$output"
