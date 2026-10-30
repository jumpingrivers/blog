test_that("make_agent registers the tools and the system prompt", {
  withr::local_envvar(GEMINI_API_KEY = "test-key")
  chat <- make_agent(
    tools = trial_tools(load_trial_data()),
    prompt_path = test_path("..", "..", "prompts", "system.md")
  )
  names <- vapply(chat$get_tools(), function(tool) tool@name, character(1))
  expect_setequal(names, c("list_arms", "count_subjects", "ae_summary", "subject_profile"))
  expect_match(chat$get_system_prompt(), "Every number in your answer")
})
