# An append-only audit log built on ALCOA principles: attributable (user),
# legible (plain text), contemporaneous (UTC time of the event), original
# (exact inputs and outputs) and accurate (a true record of what happened).
# A hash chain makes changes show.

AUDIT_FIELDS <- c(
  "ts", "user", "conversation", "event", "tool", "input", "output",
  "model", "prompt_hash", "app_version"
)

audit_open <- function(path) {
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  # The app and the MCP server can write at the same moment: the second
  # writer waits for the lock rather than failing.
  DBI::dbExecute(con, "PRAGMA busy_timeout = 5000")
  # UNIQUE prev_hash: two rows can never chain onto the same parent, so the
  # chain can't fork.
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS audit (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ts TEXT NOT NULL, user TEXT NOT NULL, conversation TEXT NOT NULL,
      event TEXT NOT NULL, tool TEXT, input TEXT, output TEXT,
      model TEXT, prompt_hash TEXT, app_version TEXT,
      prev_hash TEXT NOT NULL UNIQUE, row_hash TEXT NOT NULL
    )")
  # Enforced by the database, not by a comment.
  DBI::dbExecute(con, "
    CREATE TRIGGER IF NOT EXISTS audit_no_update BEFORE UPDATE ON audit
    BEGIN SELECT RAISE(ABORT, 'audit log is append-only'); END")
  DBI::dbExecute(con, "
    CREATE TRIGGER IF NOT EXISTS audit_no_delete BEFORE DELETE ON audit
    BEGIN SELECT RAISE(ABORT, 'audit log is append-only'); END")
  con
}

row_hash <- function(values, prev_hash) {
  digest::digest(paste(c(prev_hash, values), collapse = "\x1f"), algo = "sha256", serialize = FALSE)
}

audit_append <- function(con, entry) {
  entry$ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
  values <- vapply(AUDIT_FIELDS, function(field) {
    value <- entry[[field]]
    if (is.null(value) || length(value) == 0) "" else paste(as.character(value), collapse = "\n")
  }, character(1))
  # BEGIN IMMEDIATE takes the write lock before reading the chain's head, so
  # a second writer can't read the same head and append a sibling.
  DBI::dbExecute(con, "BEGIN IMMEDIATE")
  committed <- FALSE
  on.exit(if (!committed) DBI::dbExecute(con, "ROLLBACK"), add = TRUE)
  prev <- DBI::dbGetQuery(con, "SELECT row_hash FROM audit ORDER BY id DESC LIMIT 1")$row_hash
  prev <- if (length(prev) == 0) "start" else prev
  DBI::dbExecute(
    con,
    paste0(
      "INSERT INTO audit (", paste(c(AUDIT_FIELDS, "prev_hash", "row_hash"), collapse = ", "),
      ") VALUES (", paste(rep("?", length(AUDIT_FIELDS) + 2), collapse = ", "), ")"
    ),
    params = unname(as.list(c(values, prev, row_hash(values, prev))))
  )
  DBI::dbExecute(con, "COMMIT")
  committed <- TRUE
  invisible(TRUE)
}

# The newest row's id and hash. Keep a copy somewhere the app can't write.
audit_head <- function(con) {
  head <- DBI::dbGetQuery(con, "SELECT id, row_hash FROM audit ORDER BY id DESC LIMIT 1")
  if (nrow(head) == 0) NULL else as.list(head)
}

# The chain shows an edit to any row, unless the hashes after it were redone
# too. It can't show rows deleted from the end. A head kept elsewhere shows
# both: that row must still be there, with the same hash.
audit_verify <- function(con, head = NULL) {
  rows <- DBI::dbGetQuery(con, "SELECT * FROM audit ORDER BY id")
  prev <- "start"
  for (i in seq_len(nrow(rows))) {
    values <- vapply(AUDIT_FIELDS, function(field) rows[[field]][[i]], character(1))
    if (rows$prev_hash[[i]] != prev || rows$row_hash[[i]] != row_hash(values, prev)) {
      return(FALSE)
    }
    prev <- rows$row_hash[[i]]
  }
  is.null(head) || identical(rows$row_hash[rows$id == head$id], head$row_hash)
}

# One logger per session. Identity comes from the platform, never from the
# model or the request.
make_audit_log <- function(con, user, conversation, model, prompt_hash, app_version) {
  function(event, tool = NULL, input = NULL, output = NULL) {
    if (is.list(input)) input <- jsonlite::toJSON(input, auto_unbox = TRUE, null = "null")
    audit_append(con, list(
      user = user, conversation = conversation, event = event, tool = tool,
      input = input, output = output, model = model,
      prompt_hash = prompt_hash, app_version = app_version
    ))
  }
}

current_user <- function(session) {
  session$user %||% "local-unauthenticated"
}

# Every tool call is logged before it runs. If the log can't be written, the
# tool fails: no answer without a record.
with_audit <- function(tools, log) {
  lapply(tools, function(tool) {
    name <- tool@name
    wrap_tool(tool, function(run, args) {
      log("tool_call", tool = name, input = args)
      result <- tryCatch(run(), error = function(e) {
        log("tool_error", tool = name, input = args, output = conditionMessage(e))
        stop(e)
      })
      log("tool_result", tool = name, input = args, output = result)
      result
    })
  })
}
