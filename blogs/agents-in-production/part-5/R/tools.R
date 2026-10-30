# The agent's tools. Each function takes the trial data first and returns JSON.
# trial_tools() binds them to one copy of the data as ellmer tools.

# Arguments arrive from a model or an MCP client, and MCP clients aren't held
# to the tool's schema. A list, or text where TRUE/FALSE belongs, would quietly
# change the count, so anything but one value of the right type is an error.
check_flag <- function(value, name) {
  if (is.null(value)) return(FALSE)
  if (!is.logical(value) || length(value) != 1 || is.na(value)) {
    stop("`", name, "` must be true or false.", call. = FALSE)
  }
  value
}

check_string <- function(value, name, required = FALSE) {
  if (is.null(value) && !required) return(NULL)
  if (!is.character(value) || length(value) != 1 || is.na(value)) {
    stop("`", name, "` must be a single piece of text.", call. = FALSE)
  }
  value
}

check_count <- function(value, name, default) {
  if (is.null(value)) return(default)
  if (!is.numeric(value) || length(value) != 1 || is.na(value)) {
    stop("`", name, "` must be a single number.", call. = FALSE)
  }
  as.integer(value)
}

check_arm <- function(arm) {
  arm <- check_string(arm, "arm")
  if (is.null(arm)) return(NULL)
  if (!arm %in% ARMS) {
    stop("Unknown arm. The arms are ", paste(ARMS, collapse = ", "), ".", call. = FALSE)
  }
  arm
}

# Match a term or body system case-insensitively. An unknown value is an error,
# never a silent zero: a zero that means "I didn't understand" is worse. The
# error doesn't repeat the value, which may carry the user's own words and
# would reach the traces.
check_known <- function(value, known, what, hint) {
  if (is.null(value)) return(NULL)
  wanted <- toupper(trimws(value))
  match <- known[toupper(known) == wanted]
  if (length(match) == 0) {
    # Name the nearest real terms: ae_summary lists at most 50, so a rare term
    # (like one of the serious events) can't be found by browsing.
    close <- unique(c(
      known[grepl(wanted, toupper(known), fixed = TRUE)],
      sharing_words(wanted, known)
    ))
    closest <- if (length(close) > 0) {
      paste0(" Closest in this trial: ", paste(utils::head(close, 5), collapse = ", "), ".")
    } else {
      ""
    }
    stop("Unknown ", what, ".", closest, " ", hint, call. = FALSE)
  }
  match[[1]]
}

# The real values that share the most words with the request. Words are
# compared by their first four letters, so "dizzy" finds DIZZINESS, and
# "itching" finds nothing rather than a lookalike such as VOMITING.
sharing_words <- function(wanted, known) {
  stems <- function(text) {
    words <- strsplit(toupper(text), "[^A-Z]+")[[1]]
    unique(substr(words[nchar(words) >= 4], 1, 4))
  }
  wanted <- stems(wanted)
  shared <- vapply(known, function(value) sum(stems(value) %in% wanted), numeric(1))
  known[shared > 0 & shared == max(shared)]
}

filter_arm <- function(data, arm) {
  if (is.null(arm)) return(data)
  data$subjects <- dplyr::filter(data$subjects, ACTARM == arm)
  data$events <- dplyr::filter(data$events, ACTARM == arm)
  data
}

list_arms <- function(data) {
  counts <- dplyr::count(data$subjects, arm = ACTARM, name = "subjects")
  jsonlite::toJSON(counts, dataframe = "rows")
}

count_subjects <- function(data, arm = NULL, serious_only = FALSE, term = NULL, body_system = NULL) {
  arm <- check_arm(arm)
  serious_only <- check_flag(serious_only, "serious_only")
  term <- check_known(
    check_string(term, "term"), data$terms, "preferred term",
    "ae_summary lists the terms used in this trial."
  )
  body_system <- check_known(
    check_string(body_system, "body_system"), data$body_systems, "body system",
    "ae_summary with by = 'body_system' lists them."
  )
  data <- filter_arm(data, arm)
  events <- data$events
  if (serious_only) events <- dplyr::filter(events, AESER == "Y")
  if (!is.null(term)) events <- dplyr::filter(events, AEDECOD == term)
  if (!is.null(body_system)) events <- dplyr::filter(events, AEBODSYS == body_system)
  n <- dplyr::n_distinct(events$USUBJID)
  total <- nrow(data$subjects)
  jsonlite::toJSON(list(
    arm = arm %||% "All arms",
    # Say what was counted, so a wrong reading of the question shows.
    filters = list(
      serious_only = serious_only,
      term = term %||% "any",
      body_system = body_system %||% "any"
    ),
    subjects_with_event = n,
    subjects_in_arm = total,
    percent = round(100 * n / total, 1)
  ), auto_unbox = TRUE)
}

ae_summary <- function(data, arm = NULL, by = "term", top_n = 10L, serious_only = FALSE) {
  arm <- check_arm(arm)
  by <- match.arg(check_string(by, "by") %||% "term", c("term", "body_system"))
  top_n <- min(max(check_count(top_n, "top_n", 10L), 1L), 50L)
  serious_only <- check_flag(serious_only, "serious_only")
  column <- if (by == "term") "AEDECOD" else "AEBODSYS"
  data <- filter_arm(data, arm)
  events <- data$events
  if (serious_only) events <- dplyr::filter(events, AESER == "Y")
  rows <- events |>
    dplyr::distinct(USUBJID, event = .data[[column]]) |>
    dplyr::count(event, name = "subjects") |>
    dplyr::arrange(dplyr::desc(subjects), event) |>
    dplyr::slice_head(n = top_n) |>
    dplyr::mutate(percent = round(100 * subjects / nrow(data$subjects), 1))
  jsonlite::toJSON(list(
    arm = arm %||% "All arms",
    serious_only = serious_only,
    subjects_in_arm = nrow(data$subjects),
    by = by,
    rows = rows
  ), auto_unbox = TRUE, dataframe = "rows")
}

subject_profile <- function(data, usubjid, blinded = FALSE) {
  usubjid <- trimws(check_string(usubjid, "usubjid", required = TRUE))
  if (!grepl("^01-[0-9]{3}-[0-9]{4}$", usubjid)) {
    stop("Subject IDs look like 01-701-1015.", call. = FALSE)
  }
  subject <- dplyr::filter(data$subjects, USUBJID == usubjid)
  if (nrow(subject) == 0) {
    stop("That subject is not in the safety population.", call. = FALSE)
  }
  events <- data$events |>
    dplyr::filter(USUBJID == usubjid) |>
    # Coded terms only: free text typed by a person never reaches the model.
    dplyr::select(
      preferred_term = AEDECOD, body_system = AEBODSYS,
      serious = AESER, severity = AESEV, start = ASTDT
    )
  # In a blinded study, the arm unblinds the patient, and dates with age, sex
  # and race can help identify them.
  if (blinded) {
    subject$ACTARM <- NULL
    events$start <- NULL
  }
  jsonlite::toJSON(
    list(subject = as.list(subject), events = events),
    auto_unbox = TRUE, dataframe = "rows", Date = "ISO8601"
  )
}

trial_tools <- function(data = load_trial_data(), blinded = FALSE) {
  arm_type <- ellmer::type_enum(ARMS, "Treatment arm. Leave out to cover all arms.", required = FALSE)
  list(
    ellmer::tool(
      function() list_arms(data),
      name = "list_arms",
      description = "List the treatment arms and how many subjects are in each. Counts the safety population only.",
      annotations = ellmer::tool_annotations(title = "Listing arms", read_only_hint = TRUE)
    ),
    ellmer::tool(
      function(arm = NULL, serious_only = FALSE, term = NULL, body_system = NULL) {
        count_subjects(data, arm, serious_only, term, body_system)
      },
      name = "count_subjects",
      description = paste(
        "Count subjects in the safety population with at least one treatment-emergent",
        "adverse event matching the filters. Returns the count, the number of subjects",
        "in the arm and the percentage."
      ),
      arguments = list(
        arm = arm_type,
        serious_only = ellmer::type_boolean("Only count serious adverse events.", required = FALSE),
        term = ellmer::type_string(
          "MedDRA preferred term, e.g. 'PRURITUS'. Leave out to count any event.",
          required = FALSE
        ),
        body_system = ellmer::type_string(
          "MedDRA body system, e.g. 'NERVOUS SYSTEM DISORDERS'. Leave out for any.",
          required = FALSE
        )
      ),
      annotations = ellmer::tool_annotations(title = "Counting subjects", read_only_hint = TRUE)
    ),
    ellmer::tool(
      function(arm = NULL, by = "term", top_n = 10L, serious_only = FALSE) {
        ae_summary(data, arm, by, top_n, serious_only)
      },
      name = "ae_summary",
      description = paste(
        "List the most common treatment-emergent adverse events by preferred term",
        "or by body system, with subject counts and percentages."
      ),
      arguments = list(
        arm = arm_type,
        by = ellmer::type_enum(c("term", "body_system"), "Group by preferred term or by body system.", required = FALSE),
        top_n = ellmer::type_integer("How many rows to return, 1 to 50. Default 10.", required = FALSE),
        serious_only = ellmer::type_boolean("Only include serious adverse events.", required = FALSE)
      ),
      annotations = ellmer::tool_annotations(title = "Summarising adverse events", read_only_hint = TRUE)
    ),
    ellmer::tool(
      function(usubjid) subject_profile(data, usubjid, blinded),
      name = "subject_profile",
      description = paste(
        "Show one subject's demographics and adverse events. Patient-level data:",
        "only use it when the user asks about a specific subject."
      ),
      arguments = list(usubjid = ellmer::type_string("Subject ID, e.g. '01-701-1015'.")),
      annotations = ellmer::tool_annotations(title = "Opening a patient record", read_only_hint = TRUE)
    )
  )
}
