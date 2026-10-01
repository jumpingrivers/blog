# Patient-level tools need a reviewer's approval, asked for in the app.
# The check sits in the chat's on_tool_request() callback, outside the tools,
# so it only applies to this app. An MCP client calling the same tools would
# skip it, which is why part 5 leaves subject_profile out of the MCP server.

REVIEWER_GROUP <- "trial-reviewers"
PATIENT_TOOLS <- "subject_profile"

can_view_patients <- function(groups) {
  REVIEWER_GROUP %in% groups
}

# Groups come from Posit Connect. Running locally, TRIAL_DEV_GROUPS stands in,
# and it is ignored on Connect so it can't widen access there. Connect sets
# POSIT_PRODUCT, and the older RSTUDIO_PRODUCT while it is being phased out.
user_groups <- function(session) {
  if ("CONNECT" %in% Sys.getenv(c("POSIT_PRODUCT", "RSTUDIO_PRODUCT"))) {
    return(session$groups %||% character())
  }
  session$groups %||% strsplit(Sys.getenv("TRIAL_DEV_GROUPS"), ",")[[1]]
}

# `ask(usubjid)` returns a promise of TRUE (allow) or FALSE (decline).
# Every decision goes to `log`: a refused or declined request never reaches
# the tool, so the tool's own audit rows can't record it.
approval_callback <- function(groups, ask, log = function(...) invisible()) {
  coro::async(function(request) {
    if (!request@name %in% PATIENT_TOOLS) return(invisible())
    record <- function(event, output = NULL) {
      log(event, tool = request@name, input = request@arguments, output = output)
    }
    if (!can_view_patients(groups)) {
      record("approval_refused", "not in the reviewer group")
      ellmer::tool_reject("This user does not have access to patient-level data.")
    }
    allowed <- coro::await(ask(request@arguments$usubjid))
    if (!isTRUE(allowed)) {
      record("approval_declined")
      ellmer::tool_reject("The reviewer declined access to this patient's record.")
    }
    record("approval_granted")
    invisible()
  })
}

# Ask one question at a time. The model can request two patient records at
# once, and Shiny has one modal slot: a second dialog would replace the first
# and leave its promise waiting forever.
one_at_a_time <- function(ask) {
  queue <- promises::promise_resolve(NULL)
  function(usubjid) {
    answer <- promises::then(queue, function(...) ask(usubjid))
    # The next question waits for this one, whatever its outcome.
    queue <<- promises::then(answer, function(...) NULL, function(...) NULL)
    answer
  }
}

# A modal dialog asking the signed-in reviewer to allow one patient-level call.
ask_reviewer <- function(session) {
  one_at_a_time(function(usubjid) {
    promises::promise(function(resolve, reject) {
      id <- paste0("approval_", as.integer(stats::runif(1, 1, 1e9)))
      yes <- paste0(id, "_yes")
      no <- paste0(id, "_no")
      shiny::showModal(shiny::modalDialog(
        title = "Open a patient record?",
        paste0("The assistant wants to read the record for subject ", usubjid, "."),
        footer = shiny::tagList(
          shiny::actionButton(no, "Decline"),
          shiny::actionButton(yes, "Allow", class = "btn-primary")
        ),
        easyClose = FALSE
      ), session = session)
      answer <- function(value) {
        shiny::removeModal(session)
        resolve(value)
      }
      shiny::observeEvent(session$input[[yes]], answer(TRUE), once = TRUE, ignoreInit = TRUE, domain = session)
      shiny::observeEvent(session$input[[no]], answer(FALSE), once = TRUE, ignoreInit = TRUE, domain = session)
    })
  })
}
