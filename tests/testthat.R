# Run the installed package's behavioral and native integration tests.
library(testthat)
library(tidyonnx)

test_check("tidyonnx")
