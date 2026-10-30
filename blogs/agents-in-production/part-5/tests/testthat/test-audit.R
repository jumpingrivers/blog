new_log <- function() {
  path <- withr::local_tempfile(fileext = ".sqlite", .local_envir = parent.frame())
  con <- audit_open(path)
  withr::defer(DBI::dbDisconnect(con), envir = parent.frame())
  con
}

entry <- function(event) {
  list(user = "pedro", conversation = "c1", event = event, model = "m", prompt_hash = "p", app_version = "v")
}

test_that("appended rows form a valid chain", {
  con <- new_log()
  audit_append(con, entry("question"))
  audit_append(con, entry("answer"))
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM audit")$n, 2)
  expect_true(audit_verify(con))
})

test_that("the database refuses updates and deletes", {
  con <- new_log()
  audit_append(con, entry("question"))
  expect_error(DBI::dbExecute(con, "UPDATE audit SET user = 'someone else'"), "append-only")
  expect_error(DBI::dbExecute(con, "DELETE FROM audit"), "append-only")
})

test_that("an edit made around the triggers breaks the chain", {
  con <- new_log()
  audit_append(con, entry("question"))
  audit_append(con, entry("answer"))
  DBI::dbExecute(con, "DROP TRIGGER audit_no_update")
  DBI::dbExecute(con, "UPDATE audit SET user = 'someone else' WHERE id = 1")
  expect_false(audit_verify(con))
})

test_that("rows deleted from the end show only against a head kept elsewhere", {
  con <- new_log()
  for (event in c("question", "tool_call", "answer")) audit_append(con, entry(event))
  head <- audit_head(con)
  DBI::dbExecute(con, "DROP TRIGGER audit_no_delete")
  DBI::dbExecute(con, "DELETE FROM audit WHERE id = 3")
  expect_true(audit_verify(con))
  expect_false(audit_verify(con, head))
})

test_that("a log rehashed from an edited row on shows only against a kept head", {
  con <- new_log()
  for (event in c("question", "tool_call", "answer")) audit_append(con, entry(event))
  head <- audit_head(con)
  DBI::dbExecute(con, "DROP TRIGGER audit_no_update")
  DBI::dbExecute(con, "UPDATE audit SET user = 'someone else' WHERE id = 2")
  # The hash has no secret, so anyone who can write the table can redo it.
  rows <- DBI::dbGetQuery(con, "SELECT * FROM audit ORDER BY id")
  prev <- rows$row_hash[[1]]
  for (i in 2:3) {
    values <- vapply(AUDIT_FIELDS, function(field) rows[[field]][[i]], character(1))
    new_hash <- row_hash(values, prev)
    DBI::dbExecute(con, "UPDATE audit SET prev_hash = ?, row_hash = ? WHERE id = ?", params = list(prev, new_hash, i))
    prev <- new_hash
  }
  expect_true(audit_verify(con))
  expect_false(audit_verify(con, head))
})

test_that("a kept head still verifies as the log grows", {
  con <- new_log()
  audit_append(con, entry("question"))
  head <- audit_head(con)
  audit_append(con, entry("answer"))
  expect_true(audit_verify(con, head))
})

test_that("with_audit logs the call and the result", {
  con <- new_log()
  log <- make_audit_log(con, "pedro", "c1", "m", "p", "v")
  tools <- with_audit(trial_tools(load_trial_data()), log)
  tools[[2]](arm = "Placebo", term = "PRURITUS")
  rows <- DBI::dbGetQuery(con, "SELECT event, tool, input, output FROM audit ORDER BY id")
  expect_equal(rows$event, c("tool_call", "tool_result"))
  expect_equal(rows$tool, c("count_subjects", "count_subjects"))
  expect_match(rows$input[[1]], '"arm":"Placebo"', fixed = TRUE)
  expect_match(rows$output[[2]], '"subjects_with_event":8', fixed = TRUE)
})

test_that("a failed tool call is logged as an error and still fails", {
  con <- new_log()
  log <- make_audit_log(con, "pedro", "c1", "m", "p", "v")
  tools <- with_audit(trial_tools(load_trial_data()), log)
  expect_error(tools[[2]](term = "itching"), "Unknown preferred term")
  expect_equal(DBI::dbGetQuery(con, "SELECT event FROM audit ORDER BY id")$event, c("tool_call", "tool_error"))
})

test_that("if the log can't be written, the tool doesn't answer", {
  ran <- FALSE
  tool <- ellmer::tool(function() {
    ran <<- TRUE
    "data"
  }, name = "probe", description = "A probe.")
  broken_log <- function(...) stop("database is locked")
  audited <- with_audit(list(tool), broken_log)[[1]]
  expect_error(audited(), "database is locked")
  expect_false(ran)
})

test_that("the user comes from the session, with a clear local fallback", {
  expect_equal(current_user(list(user = "pedro")), "pedro")
  expect_equal(current_user(list(user = NULL)), "local-unauthenticated")
})

test_that("the database refuses a second row chained to the same parent", {
  con <- new_log()
  audit_append(con, entry("question"))
  head <- DBI::dbGetQuery(con, "SELECT prev_hash FROM audit WHERE id = 1")$prev_hash
  expect_error(
    DBI::dbExecute(con, "INSERT INTO audit (ts, user, conversation, event, prev_hash, row_hash)
                         VALUES ('t', 'u', 'c', 'fork', ?, 'x')", params = list(head)),
    "UNIQUE"
  )
})

test_that("a second writer waits for the first instead of failing", {
  path <- withr::local_tempfile(fileext = ".sqlite")
  con <- audit_open(path)
  withr::defer(DBI::dbDisconnect(con))
  audit_append(con, entry("question"))
  # Another process (the MCP server, say) holds the write lock for a moment.
  holder <- callr::r_bg(function(path) {
    con <- DBI::dbConnect(RSQLite::SQLite(), path)
    DBI::dbExecute(con, "PRAGMA busy_timeout = 5000")
    DBI::dbExecute(con, "BEGIN IMMEDIATE")
    Sys.sleep(2)
    DBI::dbExecute(con, "COMMIT")
    DBI::dbDisconnect(con)
  }, args = list(path = path))
  withr::defer(holder$kill())
  probe <- DBI::dbConnect(RSQLite::SQLite(), path)
  withr::defer(DBI::dbDisconnect(probe))
  locked <- FALSE
  deadline <- Sys.time() + 10
  while (!locked && Sys.time() < deadline) {
    locked <- tryCatch({
      DBI::dbExecute(probe, "BEGIN IMMEDIATE")
      DBI::dbExecute(probe, "ROLLBACK")
      FALSE
    }, error = function(e) TRUE)
    if (!locked) Sys.sleep(0.05)
  }
  expect_true(locked, info = paste(holder$read_all_error_lines(), collapse = "\n"))
  expect_no_error(audit_append(con, entry("answer")))
  expect_true(audit_verify(con))
})
