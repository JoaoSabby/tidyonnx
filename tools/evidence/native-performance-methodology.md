# Compiler performance comparison

Ratio = median GCC seconds / median Intel seconds; values above 1 favor Intel.
The API measurements include R overhead and automatic garbage collection.
Training, process startup, file output, and compilation are excluded from API timings.
Compilation/installation wall times are recorded separately in build-seconds.csv.
Rejected arithmetic profiles retain diagnostic timings but are not accepted speedups.
The strict native profile and GCC must match every saved reference exactly.
These are observed results for this runner, not a general compiler ranking.
