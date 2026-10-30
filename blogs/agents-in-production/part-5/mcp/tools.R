# Tools served over MCP, sourced by mcptools::mcp_server() from this folder.
# Run mcp/build.R first so the shared R files are in mcp/R.
for (file in c("R/data.R", "R/tools.R", "R/wrap.R", "R/audit.R")) source(file)

audit_con <- audit_open(Sys.getenv("TRIAL_AUDIT_DB", "audit.sqlite"))
audit_log <- make_audit_log(
  audit_con,
  # mcptools can't tell us who is calling, so the log records which door
  # they came through: the Connect group allowed to reach this content.
  user = Sys.getenv("TRIAL_MCP_AUDIENCE", "mcp-caller-unknown"),
  conversation = "mcp",
  model = "chosen by the MCP client",
  prompt_hash = "",
  app_version = Sys.getenv("APP_VERSION", "dev")
)

# Only the counting tools, by name. Patient records stay in the app, where a
# reviewer confirms each call, and a tool added to trial_tools() later stays
# off this server until someone adds it here.
served <- c("list_arms", "count_subjects", "ae_summary")
tools <- Filter(function(tool) tool@name %in% served, trial_tools(load_trial_data()))
with_audit(tools, audit_log)
