test_that("numbers are extracted as whole numbers and decimals", {
  expect_equal(extract_numbers("25 of 72 subjects (34.7%)"), c(25, 72, 34.7))
  expect_equal(extract_numbers("no numbers here"), numeric())
})

test_that("numbers found in the sources pass", {
  sources <- '{"subjects_with_event":25,"subjects_in_arm":72,"percent":34.7}'
  expect_equal(unverified_numbers("25 of 72 subjects (34.7%) had pruritus.", sources), numeric())
})

test_that("a rounded or invented number is flagged", {
  sources <- '{"subjects_with_event":25,"subjects_in_arm":72,"percent":34.7}'
  expect_equal(unverified_numbers("About 35% of 72 subjects.", sources), 35)
})

test_that("the numbers that label a numbered list aren't flagged", {
  # Found in the browser: a ranked list's "2." to "6." were flagged as made up.
  sources <- '{"rows":[{"event":"PRURITUS","subjects":25,"percent":34.7},{"event":"RASH","subjects":8,"percent":11.1}]}'
  answer <- "1. **Pruritus**: 25 subjects (34.7%)\n2. **Rash**: 8 subjects (11.1%)"
  expect_equal(unverified_numbers(answer, sources), numeric())
})

test_that("a made-up number inside a numbered list is still flagged", {
  sources <- '{"rows":[{"event":"PRURITUS","subjects":25,"percent":34.7}]}'
  expect_equal(unverified_numbers("1. **Pruritus**: 25 subjects (35%)", sources), 35)
  expect_equal(unverified_numbers("1) Pruritus in 26 subjects", sources), 26)
})

test_that("the check reads the last round of a chat", {
  request <- ellmer::ContentToolRequest(id = "1", name = "count_subjects", arguments = list())
  round <- ellmer::Round(
    input = list(ellmer::UserTurn(list(ellmer::ContentText("How many high-dose subjects had pruritus?")))),
    response = list(
      ellmer::AssistantTurn(list(request)),
      ellmer::UserTurn(list(ellmer::ContentToolResult(
        value = '{"subjects_with_event":25,"subjects_in_arm":72}', request = request
      ))),
      ellmer::AssistantTurn(list(ellmer::ContentText("25 of 72 subjects, about 35%.")))
    )
  )
  chat <- list(
    last_round = function() round,
    get_turns = function() c(round@input, round@response),
    get_system_prompt = function() "Study 01."
  )
  expect_equal(check_numbers(chat), 35)
})

test_that("a number from an earlier question's tool result passes", {
  # Found in the browser: asked to compare two patients, the model reused one
  # patient's age from an earlier question, and the check flagged it.
  request <- ellmer::ContentToolRequest(id = "1", name = "subject_profile", arguments = list())
  earlier <- list(
    ellmer::UserTurn(list(ellmer::ContentText("Show me subject 01-701-1015."))),
    ellmer::AssistantTurn(list(request)),
    ellmer::UserTurn(list(ellmer::ContentToolResult(value = '{"AGE":63}', request = request))),
    ellmer::AssistantTurn(list(ellmer::ContentText("A woman aged 63.")))
  )
  round <- ellmer::Round(
    input = list(ellmer::UserTurn(list(ellmer::ContentText("How old was she?")))),
    response = list(ellmer::AssistantTurn(list(ellmer::ContentText("She was 63, not 64."))))
  )
  chat <- list(
    last_round = function() round,
    get_turns = function() c(earlier, round@input, round@response),
    get_system_prompt = function() "Study 01."
  )
  expect_equal(check_numbers(chat), 64)
})

test_that("a number written before a tool call is checked too", {
  # The user sees every assistant turn of the round as it streams, not only
  # the last one.
  request <- ellmer::ContentToolRequest(id = "1", name = "count_subjects", arguments = list())
  round <- ellmer::Round(
    input = list(ellmer::UserTurn(list(ellmer::ContentText("How many high-dose subjects had pruritus?")))),
    response = list(
      ellmer::AssistantTurn(list(ellmer::ContentText("Roughly 40% did. Let me count."), request)),
      ellmer::UserTurn(list(ellmer::ContentToolResult(
        value = '{"subjects_with_event":25,"subjects_in_arm":72}', request = request
      ))),
      ellmer::AssistantTurn(list(ellmer::ContentText("25 of 72 subjects.")))
    )
  )
  chat <- list(
    last_round = function() round,
    get_turns = function() c(round@input, round@response),
    get_system_prompt = function() "Study 01."
  )
  expect_equal(check_numbers(chat), 40)
})
