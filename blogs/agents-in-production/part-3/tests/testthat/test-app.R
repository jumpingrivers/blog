test_that("each session gets a client with the trial tools", {
  withr::local_envvar(GEMINI_API_KEY = "test-key")
  shiny::testServer(test_path("..", ".."), {
    tool_names <- vapply(client$get_tools(), function(tool) tool@name, character(1))
    expect_setequal(tool_names, c("list_arms", "count_subjects", "ae_summary", "subject_profile", "escalate"))
  })
})

test_that("errors in the chat are sanitised, so raw provider messages stay out of it", {
  withr::local_options(shiny.sanitize.errors = FALSE)
  withr::local_envvar(
    GEMINI_API_KEY = "test-key",
    TRIAL_AUDIT_DB = withr::local_tempfile(fileext = ".sqlite")
  )
  shiny::testServer(test_path("..", ".."), expect_true(getOption("shiny.sanitize.errors")))
})

test_that("two sessions never share a client", {
  withr::local_envvar(GEMINI_API_KEY = "test-key")
  # One app, as on a server: both sessions run inside it. Given a folder,
  # testServer() builds a fresh app each time, which would hide a shared client.
  app <- shiny::shinyAppDir(test_path("..", ".."))
  seen <- new.env()
  for (i in 1:2) {
    shiny::testServer(app, assign(paste0("client", i), chat$client, envir = seen))
  }
  expect_false(identical(seen$client1, seen$client2))
})

test_that("the app starts in a browser and greets the user", {
  # Opt-in: when headless Chrome can't start, chromote leaves each attempt's
  # Chrome running (about 20 per run, each with a ~160 MB profile in Temp).
  skip_if_not(
    identical(Sys.getenv("TRIAL_BROWSER_TESTS"), "true"),
    "browser tests are opt-in: set TRIAL_BROWSER_TESTS=true"
  )
  withr::local_envvar(GEMINI_API_KEY = "test-key")
  app <- shinytest2::AppDriver$new(test_path("..", ".."), name = "start", load_timeout = 60000)
  withr::defer(app$stop())
  expect_match(app$get_text("body"), "only know this trial's safety data", fixed = TRUE)
})

test_that("every tool works through the app's display layer", {
  withr::local_envvar(GEMINI_API_KEY = "test-key")
  shiny::testServer(test_path("..", ".."), {
    tools <- client$get_tools()
    calls <- list(
      list_arms = list(),
      count_subjects = list(arm = "Placebo", term = "PRURITUS"),
      ae_summary = list(top_n = 3L),
      subject_profile = list(usubjid = "01-701-1015"),
      escalate = list(reason = "Asks whether to stop treatment.")
    )
    for (name in names(calls)) {
      result <- do.call(tools[[name]], calls[[name]])
      expect_true(S7::S7_inherits(result, ellmer::ContentToolResult), info = name)
    }
  })
})

test_that("TRIAL_BLINDED keeps the arm out of the app's patient records", {
  withr::local_envvar(GEMINI_API_KEY = "test-key", TRIAL_BLINDED = "true")
  seen <- new.env()
  shiny::testServer(test_path("..", ".."), {
    seen$record <- client$get_tools()$subject_profile(usubjid = "01-701-1015")
  })
  record <- jsonlite::fromJSON(seen$record@value)
  expect_false("ACTARM" %in% names(record$subject))
})
