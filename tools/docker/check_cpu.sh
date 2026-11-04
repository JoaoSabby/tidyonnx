#!/bin/sh
# Containerized preflight rejects incompatible hosts before downloading the Intel toolchain.
set -eu
flags=$(sed -n 's/^flags[[:space:]]*:[[:space:]]*/ /p' /proc/cpuinfo | head -1)
grep -m1 'model name' /proc/cpuinfo
printf '%s\n' "$flags"
for feature in avx2 fma avx512f avx512dq avx512cd avx512bw avx512vl avx512_vnni; do
  case "$flags " in
    *" $feature "*) ;;
    *) echo "Missing required CPU feature: $feature. Reference validation blocked." >&2
       exit 1 ;;
  esac
done
echo "Cascade Lake CPU feature preflight passed."
