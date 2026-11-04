#!/bin/bash
# Intel runtime paths must be initialized for both image construction and test execution.
set -eo pipefail
source /opt/intel/oneapi/setvars.sh >/dev/null
export R_MAKEVARS_USER=/opt/tidyonnx/intel_profile.mk
export R_MAKEVARS_SITE=/dev/null
export MKL_NUM_THREADS=1
export OMP_NUM_THREADS=1
exec "$@"
