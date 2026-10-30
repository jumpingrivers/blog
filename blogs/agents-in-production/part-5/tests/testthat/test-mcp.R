test_that("the MCP server serves the aggregate tools only, and logs calls", {
  root <- normalizePath(test_path("..", ".."))
  withr::with_dir(root, source(file.path("mcp", "build.R")))
  audit_path <- withr::local_tempfile(fileext = ".sqlite")
  port <- httpuv::randomPort()

  # Start the server with the documented command, in a fresh R process whose
  # environment has none of the library paths renv set for this test process,
  # as in a new terminal.
  shell_env <- Sys.getenv()
  shell_env <- setNames(as.character(shell_env), names(shell_env))
  shell_env <- shell_env[!grepl("^(R_LIBS|RENV_)", names(shell_env))]
  server <- processx::process$new(
    file.path(R.home("bin"), "Rscript"),
    c("-e", sprintf(
      "setwd('mcp'); mcptools::mcp_server(tools = 'tools.R', type = 'http', port = %d, session_tools = FALSE)", port
    )),
    wd = root,
    env = c(shell_env, TRIAL_AUDIT_DB = audit_path, TRIAL_MCP_AUDIENCE = "group:trial-analysts"),
    stdout = "|", stderr = "|"
  )
  withr::defer(server$kill())

  config <- withr::local_tempfile(fileext = ".json")
  jsonlite::write_json(
    list(mcpServers = list(trial = list(url = sprintf("http://127.0.0.1:%d/mcp", port)))),
    config, auto_unbox = TRUE
  )
  tools <- NULL
  deadline <- Sys.time() + 30
  while (is.null(tools) && Sys.time() < deadline && server$is_alive()) {
    tools <- tryCatch(mcptools::mcp_tools(config), error = function(e) {
      Sys.sleep(0.5)
      NULL
    })
  }
  expect_false(is.null(tools), info = paste(server$read_all_error_lines(), collapse = "\n"))

  names <- vapply(tools, function(tool) tool@name, character(1))
  expect_setequal(names, c("list_arms", "count_subjects", "ae_summary"))

  count <- tools[[which(names == "count_subjects")]]
  result <- count(arm = "Placebo", term = "PRURITUS")
  expect_match(paste(unlist(result), collapse = " "), '"subjects_with_event":8', fixed = TRUE)

  con <- DBI::dbConnect(RSQLite::SQLite(), audit_path)
  withr::defer(DBI::dbDisconnect(con))
  rows <- DBI::dbGetQuery(con, "SELECT user, event, tool FROM audit ORDER BY id")
  expect_equal(rows$event, c("tool_call", "tool_result"))
  expect_equal(unique(rows$user), "group:trial-analysts")
})

test_that("a tool added to trial_tools() later stays off the MCP server", {
  # The server serves tools by name, so a new tool, perhaps one with patient
  # data, isn't shared with other agents until someone decides it should be.
  root <- normalizePath(test_path("..", ".."))
  sandbox <- withr::local_tempdir()
  dir.create(file.path(sandbox, "R"))
  file.copy(file.path(root, "R", c("data.R", "tools.R", "wrap.R", "audit.R")), file.path(sandbox, "R"))
  file.copy(file.path(root, "mcp", "tools.R"), sandbox)
  cat(
    "",
    ".first_tools <- trial_tools",
    "trial_tools <- function(...) {",
    "  c(.first_tools(...), list(ellmer::tool(function() 'x', name = 'new_patient_tool', description = 'Added later.')))",
    "}",
    sep = "\n", file = file.path(sandbox, "R", "tools.R"), append = TRUE
  )
  served <- callr::r(
    function(dir, db) {
      setwd(dir)
      Sys.setenv(TRIAL_AUDIT_DB = db)
      tools <- source("tools.R")$value
      vapply(tools, function(tool) tool@name, character(1))
    },
    args = list(sandbox, file.path(sandbox, "audit.sqlite")),
    libpath = .libPaths()
  )
  expect_setequal(served, c("list_arms", "count_subjects", "ae_summary"))
})
