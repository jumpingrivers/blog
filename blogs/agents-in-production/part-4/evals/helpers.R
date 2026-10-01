# A solver that gives each question a fresh agent, one question at a time,
# so the free tier's rate limits aren't hit.
agent_solver <- function(make_chat) {
  function(inputs, ...) {
    chats <- lapply(inputs, function(input) {
      chat <- make_chat()
      chat$chat(input, echo = "none")
      chat
    })
    list(
      result = vapply(chats, answer_text, character(1)),
      solver_chat = chats
    )
  }
}

# Everything the model wrote, as the user sees it. Its last turn alone would
# miss what it said before a tool call, such as declining before escalating.
answer_text <- function(chat) {
  said <- vapply(chat$get_turns(), function(turn) {
    if (S7::S7_inherits(turn, ellmer::AssistantTurn)) turn@text else ""
  }, character(1))
  paste(said[nzchar(said)], collapse = "\n\n")
}

# Correct when the target number appears as a whole number in the answer:
# a target of 25 doesn't match 254, 2.5 or 25.3. vitals' detect_includes()
# would pass "254" for a target of "25".
detect_number <- function() {
  function(samples) {
    hit <- mapply(function(result, target) {
      pattern <- paste0("(?<![0-9.])", gsub(".", "[.]", target, fixed = TRUE), "(?![0-9]|[.][0-9])")
      grepl(pattern, result, perl = TRUE)
    }, samples$result, samples$target)
    list(score = factor(ifelse(hit, "C", "I"), levels = c("I", "C"), ordered = TRUE))
  }
}
