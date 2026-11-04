# The standalone targets share the exact profile used by R package installation.
include /opt/tidyonnx/intel_profile.mk

# These targets expose evaluated values without duplicating the profile's flag lists.
.PHONY: validator cpu_probe
print-%:
	@printf '%s\n' '$($*)'

cpu_probe:
	$(CXX17) $(CXX17FLAGS) /opt/tidyonnx/cascade_probe.cpp \
	  -o /opt/tidyonnx/cascade_probe $(LDFLAGS)
	/opt/tidyonnx/cascade_probe

validator:
	$(CXX17) $(CXX17FLAGS) -I $(SOURCE_DIR)/src/ort_include \
	  $(SOURCE_DIR)/tools/validate_runtime.cpp -o $(VALIDATOR) $(LDFLAGS) -ldl

# Public shared-library symbols must survive the same compiler and linker profile.
shared_probe:
	$(CC) $(CFLAGS) -shared $(LDFLAGS) /opt/tidyonnx/shared_library_probe.c \
	  -o /opt/tidyonnx/libprofile_probe.so
	$(CC) $(CFLAGS) $(LDFLAGS) /opt/tidyonnx/shared_client_probe.c \
	  -L/opt/tidyonnx -lprofile_probe -Wl,-rpath,/opt/tidyonnx \
	  -o /opt/tidyonnx/shared_client_probe
	$(NM) -D --defined-only /opt/tidyonnx/libprofile_probe.so
	/opt/tidyonnx/shared_client_probe
