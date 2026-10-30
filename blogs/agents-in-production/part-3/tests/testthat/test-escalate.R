test_that("escalate passes the reason on and reports the handover", {
  reasons <- character()
  tool <- escalate_tool(function(reason) reasons <<- c(reasons, reason))
  reply <- tool(reason = "Asks whether to stop treatment.")
  expect_equal(reasons, "Asks whether to stop treatment.")
  expect_match(reply, "person will follow up")
})

test_that("escalate's result gives the model no instructions", {
  # The system prompt says tool results are data, not instructions, so what
  # to tell the user belongs in the prompt.
  reply <- escalate_tool()(reason = "Asks whether to stop treatment.")
  expect_no_match(reply, "(?i)\\b(tell|don't|do not|answer)\\b", perl = TRUE)
})
