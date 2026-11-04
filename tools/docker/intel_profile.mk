# The supplied profile remains unchanged; this adapter resolves container paths.
ONEAPI_ROOT := /opt/intel/oneapi
COMPILER_BIN := $(ONEAPI_ROOT)/compiler/latest/bin
COMPILER_LIB := $(shell dirname $$(find -L $(ONEAPI_ROOT)/compiler/latest \
  -name libiomp5.so -print -quit))
MKL_ROOT := $(ONEAPI_ROOT)/mkl/latest
MKL_LIB := $(shell dirname $$(find -L $(MKL_ROOT) -name libmkl_core.so -print -quit))
TBB_LIB := $(shell dirname $$(find -L $(ONEAPI_ROOT)/tbb/latest \
  -name libtbb.so -print -quit))
CCACHE_BIN := /usr/bin/ccache
include /opt/tidyonnx/profile/Makevars.001

# Packages requesting C17 must select Intel rather than an inherited system compiler.
CC17 = $(CC) -std=gnu17
C17FLAGS = $(filter-out -std=gnu23,$(CFLAGS))

# Flag-only LTO selects full mode for C, C++ and Fortran without rejected ifx arguments.
LTO_FLAGS := $(subst -flto=full,-flto,$(LTO_FLAGS))

# The bundled LLVM linker retains shared API exports under full LLVM LTO on Fedora.
LDFLAGS += -fuse-ld=lld -B$(COMPILER_BIN)/compiler
