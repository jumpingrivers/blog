test_that("the pinned package versions are installed", {
  expected <- c(
    ellmer = "0.5.0", shinychat = "0.5.0", vitals = "0.4.0",
    mcptools = "1.0.3", pharmaverseadam = "1.3.0"
  )
  installed <- vapply(names(expected), function(pkg) as.character(utils::packageVersion(pkg)), character(1))
  expect_equal(installed, expected)
})
