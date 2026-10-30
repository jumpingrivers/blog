# A real chat with a history of answered questions, each costing
# `input` + `output` tokens, plus `cached` input served from the cache.
chat_with_answers <- function(input, output, cached = 0) {
  withr::local_envvar(GEMINI_API_KEY = "test-key")
  chat <- make_agent(tools = list(), prompt_path = test_path("..", "..", "prompts", "system.md"))
  turns <- unlist(Map(function(i, o) {
    list(
      ellmer::UserTurn(list(ellmer::ContentText("Question"))),
      ellmer::AssistantTurn(list(ellmer::ContentText("Answer")), tokens = c(i, o, cached))
    )
  }, input, output), recursive = FALSE)
  chat$set_turns(turns)
  chat
}

test_that("session tokens add up input and output", {
  expect_equal(session_tokens(chat_with_answers(c(100, 200), c(10, 20))), 330)
  expect_equal(session_tokens(chat_with_answers(numeric(), numeric())), 0)
})

test_that("a request under the budget goes ahead", {
  check <- budget_check(chat_with_answers(100, 10), max_tokens = 1000)
  expect_no_error(check(list()))
})

test_that("a request over the budget is refused before it is sent", {
  check <- budget_check(chat_with_answers(900, 200), max_tokens = 1000)
  expect_error(check(list()), class = "trial_budget_exceeded")
})

test_that("a failed or cancelled request doesn't break the budget check", {
  withr::local_envvar(GEMINI_API_KEY = "test-key")
  chat <- make_agent(tools = list(), prompt_path = test_path("..", "..", "prompts", "system.md"))
  chat$set_turns(list(
    ellmer::UserTurn(list(ellmer::ContentText("First question"))),
    ellmer::AssistantTurn(list(ellmer::ContentText("First answer")), tokens = c(100, 10, 0)),
    ellmer::UserTurn(list(ellmer::ContentText("Second question"))),
    ellmer::AssistantPartialTurn(list(ellmer::ContentText("Half an ans")))
  ))
  expect_equal(session_tokens(chat), 110)
  expect_no_error(budget_check(chat, max_tokens = 1000)(list()))
})

test_that("session tokens include input served from the cache", {
  # ellmer counts cached input separately from the rest of the input.
  expect_equal(session_tokens(chat_with_answers(100, 10, cached = 50)), 160)
})

test_that("a question longer than the limit is refused before it is sent", {
  # The budget only knows the tokens already used, so one very long question
  # could spend a session's worth in a single request.
  check <- budget_check(chat_with_answers(numeric(), numeric()), max_tokens = 1000, max_chars = 100)
  question <- function(text) list(ellmer::UserTurn(list(ellmer::ContentText(text))))
  expect_error(check(question(strrep("a", 101))), class = "trial_question_too_long")
  expect_no_error(check(question(strrep("a", 100))))
})

test_that("a long tool result isn't mistaken for a long question", {
  request <- ellmer::ContentToolRequest(id = "1", name = "subject_profile", arguments = list())
  turns <- list(
    ellmer::UserTurn(list(ellmer::ContentText("Show me subject 01-701-1015."))),
    ellmer::AssistantTurn(list(request)),
    ellmer::UserTurn(list(ellmer::ContentToolResult(value = strrep("x", 5000), request = request)))
  )
  check <- budget_check(chat_with_answers(numeric(), numeric()), max_tokens = 1000, max_chars = 100)
  expect_no_error(check(turns))
})
