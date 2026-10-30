# The numbers check: every number in an answer must appear in a question, the
# system prompt or a tool result from the same conversation.

extract_numbers <- function(text) {
  found <- regmatches(text, gregexpr("[0-9]+(?:[.][0-9]+)?", text, perl = TRUE))[[1]]
  unique(as.numeric(found))
}

# The numbers that label a numbered list ("1. ", "2) ") aren't claims about
# the data, so they're dropped before the check.
LIST_MARKERS <- "(?m)^[ \t]*[0-9]+[.)][ \t]+"

unverified_numbers <- function(answer, sources) {
  allowed <- extract_numbers(paste(sources, collapse = " "))
  found <- extract_numbers(gsub(LIST_MARKERS, "", answer, perl = TRUE))
  found[!found %in% allowed]
}

# The last answer, plus everything its numbers may come from: the system
# prompt, the questions and every tool result in the conversation. As the
# system prompt allows, the model may quote a result from an earlier question.
# The answer is the text of every assistant turn in the round, since the model
# can write before a tool call as well as after it, and the user sees both.
last_round_parts <- function(chat) {
  turns <- chat$last_round()@response
  said <- vapply(turns, function(turn) {
    if (S7::S7_inherits(turn, ellmer::AssistantTurn)) turn@text else ""
  }, character(1))
  conversation <- chat$get_turns()
  results <- unlist(lapply(conversation, function(turn) {
    lapply(turn@contents, function(content) {
      if (S7::S7_inherits(content, ellmer::ContentToolResult) && is.null(content@error)) {
        as.character(content@value)
      }
    })
  }))
  questions <- vapply(conversation, function(turn) {
    if (S7::S7_inherits(turn, ellmer::UserTurn)) turn@text else ""
  }, character(1))
  list(
    answer = paste(said[nzchar(said)], collapse = "\n\n"),
    sources = c(chat$get_system_prompt(), questions, results)
  )
}

check_numbers <- function(chat) {
  parts <- last_round_parts(chat)
  unverified_numbers(parts$answer, parts$sources)
}
