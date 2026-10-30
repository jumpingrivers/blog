# A per-session token budget, checked before every model request. Tokens,
# unlike cost, are known for every provider.

# Added up from the turns rather than chat$get_tokens(), which in ellmer 0.5.0
# errors once a failed or cancelled request has left a partial turn behind.
session_tokens <- function(chat) {
  used <- vapply(chat$get_turns(), function(turn) {
    # Input, output and cached input, which ellmer counts separately.
    if (S7::S7_inherits(turn, ellmer::AssistantTurn)) sum(turn@tokens, na.rm = TRUE) else 0
  }, numeric(1))
  sum(used)
}

budget_check <- function(chat, max_tokens, max_chars = 2000) {
  function(turns) {
    # The budget only knows the tokens already used, so one very long question
    # could spend a session's worth in a single request. Tool results come
    # back as user turns too, but with no text of their own.
    newest <- if (length(turns) > 0) turns[[length(turns)]]
    if (S7::S7_inherits(newest, ellmer::UserTurn) && nchar(newest@text) > max_chars) {
      rlang::abort(
        paste0("This question is too long. Please keep it under ", format(max_chars, big.mark = ","), " characters."),
        class = "trial_question_too_long"
      )
    }
    used <- session_tokens(chat)
    if (used >= max_tokens) {
      rlang::abort(
        "This session has reached its usage limit. Reload the page to start a new session.",
        class = "trial_budget_exceeded"
      )
    }
  }
}

enforce_budget <- function(chat, max_tokens, max_chars = 2000) {
  chat$on_request_start(budget_check(chat, max_tokens, max_chars))
}
