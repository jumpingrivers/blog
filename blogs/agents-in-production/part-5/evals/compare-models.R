# Part 4: the same number evals on two models: the app's (TRIAL_MODEL) and a
# second one in TRIAL_COMPARE_MODEL, picked from ellmer::models_google_gemini()
# (pick one {ellmer} has a price for). Needs a paid key: a few hundred requests.
for (file in list.files("R", pattern = "[.]R$", full.names = TRUE)) source(file)
source("evals/helpers.R")
source("evals/dataset.R")
Sys.setenv(VITALS_LOG_DIR = "evals/logs")

data <- load_trial_data()
models <- c(Sys.getenv("TRIAL_MODEL", "gemini-3.7-flash"), Sys.getenv("TRIAL_COMPARE_MODEL"))
stopifnot("Set TRIAL_COMPARE_MODEL first" = nzchar(models[[2]]))

for (model in models) {
  make_chat <- function() {
    make_agent(tools = c(trial_tools(data), list(escalate_tool())), model = model)
  }
  task <- vitals::Task$new(
    build_number_set(),
    solver = agent_solver(make_chat),
    scorer = detect_number(),
    epochs = 3,
    name = paste0("numbers-", model)
  )
  started <- Sys.time()
  task$eval(view = FALSE)
  cat("\n==", model, "==\n")
  cat("seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs"))), "\n")
  print(task$metrics)
  print(task$get_cost())
}
