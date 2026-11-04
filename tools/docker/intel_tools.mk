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
