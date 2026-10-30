library(shiny)
library(bslib)
library(shinychat)

# shinychat writes a failed answer's error into the chat. Sanitised, it says
# "An error occurred" instead of showing the provider's raw message.
options(shiny.sanitize.errors = TRUE)

# Shiny sources every file in R/ before this runs.
trial_data <- load_trial_data()
blinded <- identical(Sys.getenv("TRIAL_BLINDED"), "true")

ui <- app_ui()

server <- function(input, output, session) {
  # One client per session. A client made outside server() would share one
  # conversation between every user.
  tools <- c(
    trial_tools(trial_data, blinded = blinded),
    list(escalate_tool(function(reason) message("Escalated: ", reason)))
  )
  client <- make_agent(tools = with_display(tools))
  client$on_tool_request(approval_callback(user_groups(session), ask_reviewer(session)))
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

  observeEvent(chat$last_turn(), {
    unverified <- check_numbers(client)
    if (length(unverified) > 0) {
      showNotification(
        paste0(
          "These numbers didn't come from the trial data: ",
          paste(unverified, collapse = ", "), ". Check them before using this answer."
        ),
        type = "warning", duration = NULL
      )
    }
  })
}

shinyApp(ui, server)
