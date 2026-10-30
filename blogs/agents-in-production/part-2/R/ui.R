# The app's page: one chat, no file uploads.

GREETING <- paste(
  "Ask me about adverse events in CDISC pilot study 01: a xanomeline skin patch at two doses, against placebo.",
  "For example: *Which adverse events were most common on the high dose?*",
  "I only know this trial's safety data, and I can't give medical advice.",
  sep = "\n\n"
)

app_ui <- function() {
  bslib::page_fillable(
    title = "Trial safety assistant",
    shinychat::chat_ui(
      "chat",
      greeting = GREETING,
      placeholder = "Ask about the trial's adverse events",
      allow_attachments = FALSE
    )
  )
}
