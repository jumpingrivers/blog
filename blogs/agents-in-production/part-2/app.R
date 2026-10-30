library(shiny)
library(bslib)
library(shinychat)

# shinychat writes a failed answer's error into the chat. Sanitised, it says
# "An error occurred" instead of showing the provider's raw message.
options(shiny.sanitize.errors = TRUE)

# Shiny sources every file in R/ before this runs.
trial_data <- load_trial_data()

ui <- app_ui()

server <- function(input, output, session) {
  # One client per session. A client made outside server() would share one
  # conversation between every user.
  client <- make_agent(tools = with_display(trial_tools(trial_data)))
  refuse_attachments(client)
  chat <- chat_server("chat", client, history = FALSE)

  observeEvent(chat$last_error(), {
    error <- chat$last_error()
    message <- if (inherits(error, "trial_attachment_refused")) {
      conditionMessage(error)
    } else {
      "The assistant couldn't answer just now. Please try again in a minute."
    }
    showNotification(message, type = "error", duration = NULL)
  })
}

shinyApp(ui, server)
