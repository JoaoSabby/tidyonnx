#!/usr/bin/env bash
# Compare generic GCC with aggressive and strict Intel native profiles on the same host.
set -euo pipefail
makevars="${1:-tools/linux/Makevars.intel-native}"
output="${2:-/artifacts/performance}"
test -f "$makevars" || { echo "Required Makevars not found: $makevars" >&2; exit 2; }
makevars="$(realpath "$makevars")"
mkdir -p "$output" /opt/performance-libs/gcc /opt/performance-libs/intel-makevars001 /opt/performance-libs/intel-native-strict
output="$(realpath "$output")"
test ! -f "$output/fixture.rds" || { echo "Use a fresh output directory." >&2; exit 2; }
export CCACHE_DISABLE=1 MAKEFLAGS=-j2
cp "$makevars" "$output/Makevars.intel-native"
sha256sum "$makevars" > "$output/Makevars.intel-native.sha256"
cat /etc/os-release > "$output/os-release.txt"
cat /proc/cpuinfo > "$output/cpu.txt"
printf 'profile,seconds\n' > "$output/build-seconds.csv"
printf '%s\n' "${SOURCE_REVISION:-unknown}" > "$output/source-revision.txt"
gcc --version > "$output/gcc-version.txt"
Rscript tools/check-policy.R

# Both compiler builds use the same two-job policy, with cache hits disabled.
cat > /tmp/Makevars.performance-gcc <<'EOF'
# Conventional generic GCC, respecting this package's C17 and C++17 requirements.
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
EOF
cp /tmp/Makevars.performance-gcc "$output/Makevars.gcc"
start="$(date +%s%N)"
R_MAKEVARS_USER=/tmp/Makevars.performance-gcc R CMD INSTALL --preclean --no-multiarch \
  --library=/opt/performance-libs/gcc . 2>&1 | tee "$output/gcc-build.log"
elapsed="$(($(date +%s%N) - start))"
printf 'gcc,%s.%09d\n' "$((elapsed / 1000000000))" "$((elapsed % 1000000000))" >> "$output/build-seconds.csv"

# Initialize the installed oneAPI toolchain and record the detected native CPU target.
set +u
source /opt/intel/oneapi/compiler/latest/env/vars.sh
set -u
export ONEAPI_ROOT=/opt/intel/oneapi
export COMPILER_BIN="$ONEAPI_ROOT/compiler/latest/bin" COMPILER_LIB="$ONEAPI_ROOT/compiler/latest/lib"
export LD_LIBRARY_PATH="$COMPILER_LIB:${LD_LIBRARY_PATH:-}"
icx --version > "$output/intel-version.txt"
icx -march=native -mtune=native -### -x c -c /dev/null > "$output/native-target.txt" 2>&1
icx -O3 -march=native tools/linux/avx512-probe.c -o /tmp/performance-avx512-probe
objdump -d /tmp/performance-avx512-probe > "$output/avx512-probe-assembly.txt"
grep -q zmm "$output/avx512-probe-assembly.txt"
/tmp/performance-avx512-probe > "$output/avx512-execution.txt"

# The strict control changes only arithmetic flags; both Intel profiles retain native and O3.
for profile in intel-makevars001 intel-native-strict; do
  if [[ "$profile" == intel-native-strict ]]; then mode=strict; else mode=fast; fi
  TIDYONNX_FP_MODE="$mode" make --no-print-directory -f "$makevars" \
    -f tools/linux/report-makevars.mk report > "$output/$profile-effective-makevars.txt"
  start="$(date +%s%N)"
  TIDYONNX_FP_MODE="$mode" R_MAKEVARS_USER="$makevars" R CMD INSTALL --preclean --no-multiarch \
    --library="/opt/performance-libs/$profile" . 2>&1 | tee "$output/$profile-build.log"
  elapsed="$(($(date +%s%N) - start))"
  printf '%s,%s.%09d\n' "$profile" "$((elapsed / 1000000000))" "$((elapsed % 1000000000))" >> "$output/build-seconds.csv"
  grep -q 'icx.*-c ' "$output/$profile-build.log"
  grep -q 'icpx.*-c ' "$output/$profile-build.log"
done

# Persist source predictions once, before measuring any converted model.
R_LIBS=/opt/performance-libs/gcc Rscript tools/linux/prepare-performance.R "$output"
sha256sum "$output/"*.ubj "$output/"*.onnx "$output/"*-reference.rds \
  "$output/inputs.rds" "$output/fixture.rds" > "$output/fixture-sha256.txt"

# Rotate process order so each compiler profile occupies every position once.
for block in 1 2 3; do
  case "$block" in
    1) profiles=(gcc intel-makevars001 intel-native-strict) ;;
    2) profiles=(intel-makevars001 intel-native-strict gcc) ;;
    3) profiles=(intel-native-strict gcc intel-makevars001) ;;
  esac
  for profile in "${profiles[@]}"; do
    R_LIBS="/opt/performance-libs/$profile" \
      Rscript tools/linux/measure-performance.R "$output" "$profile" "$block"
  done
done
sha256sum -c "$output/fixture-sha256.txt"
Rscript tools/linux/compare-performance.R "$output"
