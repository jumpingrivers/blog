# Part 5: a second agent using the trial tools over MCP. Start the server
# first, in another terminal, from this project's root (renv only activates
# there, so R started inside mcp/ can't find mcptools). Build first:
#   Rscript mcp/build.R
#   Rscript -e "setwd('mcp'); mcptools::mcp_server(tools = 'tools.R', type = 'http', port = 9000, session_tools = FALSE)"
chat <- ellmer::chat_google_gemini(
  model = "gemini-3.7-flash",
  system_prompt = "You write short safety summaries for a trial report. Use the tools for every number."
)
chat$set_tools(mcptools::mcp_tools("mcp/client-config.json"))
chat$chat("Write two sentences comparing pruritus on the high dose with placebo.", echo = "all")
