# Run the offline test suite from the project root: Rscript tests/run.R
Sys.setenv(NOT_CRAN = "true") # shinytest2 skips browser tests otherwise
testthat::test_dir("tests/testthat", stop_on_failure = TRUE)
