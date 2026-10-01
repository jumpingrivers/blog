data <- load_trial_data()

test_that("a summary becomes a markdown table", {
  md <- result_markdown(ae_summary(data, arm = "Placebo", top_n = 2))
  expect_match(md, "| event | subjects | percent |", fixed = TRUE)
  expect_match(md, "- **arm**: Placebo", fixed = TRUE)
})

test_that("a count becomes a list", {
  md <- result_markdown(count_subjects(data, serious_only = TRUE))
  expect_match(md, "- **subjects_with_event**: 3", fixed = TRUE)
})

test_that("list_arms becomes a table", {
  md <- result_markdown(list_arms(data))
  expect_match(md, "| Placebo | 86 |", fixed = TRUE)
})

test_that("with_display keeps the JSON for the model and adds a display", {
  tools <- with_display(trial_tools(data))
  result <- tools[[1]]()
  expect_true(S7::S7_inherits(result, ellmer::ContentToolResult))
  expect_s3_class(result@value, "json")
  expect_s3_class(result@extra$display, "shinychat_tool_result_display")
})

test_that("with_display passes a plain-text result through without failing the call", {
  tools <- with_display(list(escalate_tool()))
  result <- tools[[1]](reason = "Asks for medical advice.")
  expect_true(S7::S7_inherits(result, ellmer::ContentToolResult))
  expect_match(result@value, "person will follow up")
})
