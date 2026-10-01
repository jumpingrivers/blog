# Part 3: run the evals. Needs the Gemini key and about 70 to 100 requests,
# more than the free tier allows in a day. Takes a few minutes.
for (file in list.files("R", pattern = "[.]R$", full.names = TRUE)) source(file)
source("evals/helpers.R")
source("evals/dataset.R")
Sys.setenv(VITALS_LOG_DIR = "evals/logs")

data <- load_trial_data()
# The model the app uses, pinned, so an update to {ellmer}'s default can't
# change what the evals test.
model <- Sys.getenv("TRIAL_MODEL", "gemini-3.7-flash")
make_chat <- function() make_agent(tools = c(trial_tools(data), list(escalate_tool())), model = model)

numbers <- vitals::Task$new(
  dataset = build_number_set(),
  solver = agent_solver(make_chat),
  scorer = detect_number(),
  epochs = 3,
  name = "trial-numbers"
)
numbers$eval(view = FALSE)

# The judge reads only the final answer, and here it's the same model
# marking its own work. A judge from another provider is a fairer marker.
judgement <- vitals::Task$new(
  dataset = build_judgement_set(),
  solver = agent_solver(make_chat),
  scorer = vitals::model_graded_qa(scorer_chat = ellmer::chat_google_gemini(model = model)),
  epochs = 1,
  name = "trial-judgement"
)
judgement$eval(view = FALSE)

print(numbers$metrics)
print(judgement$metrics)
print(numbers$get_cost())
print(judgement$get_cost())
