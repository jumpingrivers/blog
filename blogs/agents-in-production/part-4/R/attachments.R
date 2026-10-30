# No file attachments reach the model. The chat UI offers no uploads, and
# because a crafted client could still send one, every request is checked
# here too: a user turn may hold typed text and tool results, nothing else.

attachment_check <- function() {
  allowed <- function(content) {
    if (S7::S7_inherits(content, ellmer::ContentText)) {
      # shinychat sends a text file (CSV, TXT, JSON and so on) as text in a
      # <file-attachment> wrapper, so text can be a file too.
      return(!grepl("^\\s*<file-attachment ", content@text))
    }
    S7::S7_inherits(content, ellmer::ContentToolResult)
  }
  function(turns) {
    for (turn in turns) {
      if (S7::S7_inherits(turn, ellmer::UserTurn) && !all(vapply(turn@contents, allowed, logical(1)))) {
        rlang::abort(
          "Files can't be sent to this assistant. Ask your question as text.",
          class = "trial_attachment_refused"
        )
      }
    }
  }
}

refuse_attachments <- function(chat) {
  chat$on_request_start(attachment_check())
}
