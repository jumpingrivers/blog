test_that("a wrapped tool keeps its definition and passes arguments through", {
  tools <- trial_tools(load_trial_data())
  seen <- NULL
  wrapped <- wrap_tool(tools[[2]], function(run, args) {
    seen <<- args
    run()
  })
  expect_equal(wrapped@name, "count_subjects")
  expect_equal(names(wrapped@arguments@properties), c("arm", "serious_only", "term", "body_system"))
  result <- jsonlite::fromJSON(wrapped(arm = "Placebo", term = "PRURITUS"))
  expect_equal(result$subjects_with_event, 8)
  expect_equal(seen$arm, "Placebo")
  expect_false(seen$serious_only)
})

test_that("a wrapper can replace the result", {
  tools <- trial_tools(load_trial_data())
  wrapped <- wrap_tool(tools[[1]], function(run, args) "replaced")
  expect_equal(wrapped(), "replaced")
})
