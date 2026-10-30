# Build a chat client with the system prompt and tools registered.

read_prompt <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

make_agent <- function(tools = trial_tools(), prompt_path = "prompts/system.md",
                       model = NULL, chat_fun = ellmer::chat_google_gemini) {
  chat <- chat_fun(system_prompt = read_prompt(prompt_path), model = model)
  chat$register_tools(tools)
  chat
}
