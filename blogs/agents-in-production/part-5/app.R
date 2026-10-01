library(shiny)
library(bslib)
library(shinychat)

# shinychat writes a failed answer's error into the chat. Sanitised, it says
# "An error occurred" instead of showing the provider's raw message.
options(shiny.sanitize.errors = TRUE)

# Shiny sources every file in R/ before this runs.
trial_data <- load_trial_data()
prompt_path <- "prompts/system.md"
prompt_hash <- digest::digest(read_prompt(prompt_path), algo = "sha256", serialize = FALSE)
model <- Sys.getenv("TRIAL_MODEL", "gemini-3.7-flash")
max_tokens <- as.numeric(Sys.getenv("TRIAL_MAX_TOKENS", "200000"))
max_question_chars <- as.numeric(Sys.getenv("TRIAL_MAX_QUESTION_CHARS", "2000"))
blinded <- identical(Sys.getenv("TRIAL_BLINDED"), "true")
audit_con <- audit_open(Sys.getenv("TRIAL_AUDIT_DB", "audit.sqlite"))
onStop(function() DBI::dbDisconnect(audit_con))

ui <- app_ui()

server <- function(input, output, session) {
  # Shiny uses the session token in the addresses of this session's own
  # resources, so the log and the traces get a hash of it instead.
  conversation <- substr(digest::digest(session$token, algo = "sha256", serialize = FALSE), 1, 16)
  log <- make_audit_log(
    audit_con, current_user(session), conversation, model, prompt_hash,
    Sys.getenv("APP_VERSION", "dev")
  )
  groups <- user_groups(session)
  log("session_start", output = paste(groups, collapse = ", "))
  tools <- c(
    trial_tools(trial_data, blinded = blinded),
    list(escalate_tool(function(reason) log("escalation", output = reason)))
  )

  # One client per session. A client made outside server() would share one
  # conversation between every user.
  client <- make_agent(tools = with_display(with_audit(tools, log)), prompt_path = prompt_path, model = model)
  client$conversation_id <- conversation
  client$on_tool_request(approval_callback(groups, ask_reviewer(session), log))
  enforce_budget(client, max_tokens, max_question_chars)
  refuse_attachments(client)
  client$on_request_end(function(turn) {
    log("model_response", output = sprintf(
      "tokens in %s, out %s, cached %s; cost %s",
      turn@tokens[[1]], turn@tokens[[2]], turn@tokens[[3]], turn@cost
    ))
  })

  chat <- chat_server("chat", client, history = FALSE)

  observeEvent(chat$last_input(), {
    log("question", output = paste(unlist(chat$last_input()), collapse = " "))
  })

  observeEvent(chat$last_turn(), {
    parts <- last_round_parts(client)
    log("answer", output = parts$answer)
    unverified <- unverified_numbers(parts$answer, parts$sources)
    if (length(unverified) > 0) {
      log("unverified_numbers", output = paste(unverified, collapse = ", "))
      showNotification(
        paste0(
          "These numbers didn't come from the trial data: ",
          paste(unverified, collapse = ", "), ". Check them before using this answer."
        ),
        type = "warning", duration = NULL
      )
    }
  })

  observeEvent(chat$last_error(), {
    error <- chat$last_error()
    log("error", output = conditionMessage(error))
    message <- if (inherits(error, c("trial_budget_exceeded", "trial_question_too_long", "trial_attachment_refused"))) {
      conditionMessage(error)
    } else {
      "The assistant couldn't answer just now. Please try again in a minute."
    }
    showNotification(message, type = "error", duration = NULL)
  })
}

shinyApp(ui, server)
