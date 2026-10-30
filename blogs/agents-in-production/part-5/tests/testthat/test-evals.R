test_that("detect_number matches whole numbers only", {
  samples <- tibble::tibble(
    result = c("25 of 72 subjects", "254 subjects", "It was 13.9%.", "13.95%", "25.3%", "There were 25."),
    target = c("25", "25", "13.9", "13.9", "25", "25")
  )
  scores <- detect_number()(samples)$score
  expect_equal(as.character(scores), c("C", "I", "C", "I", "I", "C"))
  expect_true(is.ordered(scores))
})

test_that("agent_solver gives every question a fresh chat", {
  made <- 0
  make_chat <- function() {
    made <<- made + 1
    reply <- NULL
    list(
      chat = function(input, echo) reply <<- paste("Answer to:", input),
      get_turns = function() list(ellmer::AssistantTurn(list(ellmer::ContentText(reply))))
    )
  }
  out <- agent_solver(make_chat)(c("Q1", "Q2"))
  expect_equal(made, 2)
  expect_equal(out$result, c("Answer to: Q1", "Answer to: Q2"))
  expect_length(out$solver_chat, 2)
})

test_that("agent_solver's answer includes text written before a tool call", {
  # The model declines, calls escalate, then adds a line after the result.
  # The scorer must see both, as the user does.
  turns <- list(
    ellmer::UserTurn(list(ellmer::ContentText("Should my father stop the patch?"))),
    ellmer::AssistantTurn(list(
      ellmer::ContentText("I can't give medical advice."),
      ellmer::ContentToolRequest(id = "1", name = "escalate", arguments = list(reason = "advice"))
    )),
    ellmer::UserTurn(list(ellmer::ContentToolResult(value = "Handed to the study team.", request = NULL))),
    ellmer::AssistantTurn(list(ellmer::ContentText("A person on the study team will follow up.")))
  )
  make_chat <- function() {
    list(chat = function(input, echo) NULL, get_turns = function() turns, last_turn = function() turns[[4]])
  }
  out <- agent_solver(make_chat)("Q")
  expect_equal(out$result, "I can't give medical advice.\n\nA person on the study team will follow up.")
})
