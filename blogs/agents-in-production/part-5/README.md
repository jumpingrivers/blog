# Agents in Production, part 5: sharing the tools over MCP

Blog post: [Agents in Production: Build an MCP Server in R with {mcptools}](https://www.jumpingrivers.com/blog/agents-in-production-mcp/)

Author: Pedro Silva

Blog Summary: Build an MCP server in R with {mcptools}: share your agent's tools with other AI agents, deploy the server to Posit Connect, and use remote MCP servers from {ellmer} with care.

This folder is the finished code of the five-part series. Each part's folder works on its own.

## Setup

You need R 4.5 and a Gemini API key. The free tier from [Google AI Studio](https://aistudio.google.com/) is enough for the app and the demos, but not for the evals or the model comparison. Free tiers aren't for confidential data, and an app you offer to colleagues in the UK, the EEA or Switzerland must use Google's paid service; part 4 explains why.

In this folder, install the pinned packages:

```r
install.packages("renv")
renv::restore()
```

Then put your key in a file called `.Renviron` in this folder (git ignores it), and restart R:

```
GEMINI_API_KEY=your-key-here
```

### Setup tips

- **Open the folder as a project**: in RStudio, File > New Project > Existing Directory, or in Positron, File > Open Folder. R only reads this folder's `.Rprofile`, which starts {renv}, and its `.Renviron` when it starts here, so `setwd()` isn't enough.
- **On Windows, you don't need Rtools.** `renv::restore(repos = c(CRAN = "https://packagemanager.posit.co/cran/2026-09-28"))` installs ready-built copies of the pinned versions from Posit Package Manager.
- **Create `.Renviron` from R**, with `file.edit(".Renviron")`, so that Notepad doesn't save it as `.Renviron.txt`. After a restart, `nzchar(Sys.getenv("GEMINI_API_KEY"))` should return `TRUE`.
- **Check for `GOOGLE_API_KEY`.** {ellmer} reads it too, and uses it first if both are set.
- **Coming from an earlier part?** Copy your `.Renviron` into this folder, since git ignores it, and run `renv::restore()` again. {renv} reuses the packages it has already installed.
- **On Windows, `Rscript` usually isn't on the PATH.** In PowerShell, give its full path, such as `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" tests/run.R`, or run each script from the R console with `source()`.
- **Without {renv}**, you get newer packages than we tested, and `tests/testthat/test-setup.R`, which checks the pinned versions, fails.

## Run

```sh
Rscript tests/run.R              # offline tests, no API calls
Rscript -e "shiny::runApp()"     # the app
```

### The MCP server

```sh
Rscript mcp/build.R              # copies the shared R files into mcp/R
Rscript -e "setwd('mcp'); mcptools::mcp_server(tools = 'tools.R', type = 'http', port = 9000, session_tools = FALSE)"
```

Start it from this folder, not from `mcp/`: {renv} only activates here. It serves `list_arms`, `count_subjects` and `ae_summary`. `subject_profile` is left out, because its reviewer approval lives in the app and wouldn't apply to MCP callers.

The server runs in `mcp/`, so by default it writes its own `mcp/audit.sqlite`. For one log, set `TRIAL_AUDIT_DB` to the same absolute path for the app and the server.

With the server running, `Rscript demo/part-5-client.R` starts a second agent that uses the tools over MCP. To deploy the server to Posit Connect, run `mcp/build.R`, then `rsconnect::deployAPI("mcp", contentCategory = "mcp")`.

### Claude Desktop

To try a local copy of the server from Claude Desktop, run `Rscript mcp/build.R`, then add this to Claude Desktop's config file and restart Claude Desktop:

```json
{
  "mcpServers": {
    "trial-safety": {
      "command": "path/to/Rscript",
      "args": ["-e", "setwd('path/to/code/mcp'); mcptools::mcp_server(tools = 'tools.R', session_tools = FALSE)"],
      "env": {
        "R_LIBS": "path/to/code/renv/library/<platform>/R-4.5/<arch>",
        "TRIAL_AUDIT_DB": "path/to/code/audit.sqlite"
      }
    }
  }
}
```

The config file is `%APPDATA%\Claude\claude_desktop_config.json` on Windows and `~/Library/Application Support/Claude/claude_desktop_config.json` on macOS, or open it from Settings > Developer > Edit Config.

- Use the full path to `Rscript` (it's in `R.home("bin")`) and forward slashes in every path, on Windows too.
- For `R_LIBS`, paste the result of `.libPaths()[1]` run in this folder, or leave it out if you installed the packages without {renv}.
- `TRIAL_AUDIT_DB` points at the app's local log, so both write to one file.

From R, use the HTTP server instead: {mcptools}' own client waits about four seconds for a local server to start, and this one takes longer.

## Settings

| Variable | Used for |
|---|---|
| `GEMINI_API_KEY` or `GOOGLE_API_KEY` | Gemini access |
| `TRIAL_MODEL` | The model's exact ID; default `gemini-3.7-flash` |
| `TRIAL_MAX_TOKENS` | Token budget per session; default 200000 |
| `TRIAL_MAX_QUESTION_CHARS` | Longest question accepted, in characters; default 2000 |
| `TRIAL_BLINDED` | `true` leaves the arm and the event dates out of patient records |
| `TRIAL_AUDIT_DB` | The SQLite audit log; default `audit.sqlite` in the folder R runs in. On Posit Connect, a file in the content's folder is deleted when you redeploy, so use Postgres there: see `sql/audit-postgres.sql` |
| `TRIAL_DEV_GROUPS` | Running locally, stands in for Connect's groups, e.g. `trial-reviewers`; ignored on Connect. Don't set it on any other server |
| `APP_VERSION` | Recorded in every audit row; set it when you deploy |
| `TRIAL_MCP_AUDIENCE` | MCP server: recorded as the caller, e.g. the Connect group allowed to reach it |
| `TRIAL_COMPARE_MODEL` | The second model for `evals/compare-models.R` |
| `OTEL_TRACES_EXPORTER`, `OTEL_EXPORTER_OTLP_TRACES_FILE` | Send {ellmer}'s traces to a file, e.g. `otlp/file` and `traces/trace-%N.jsonl` |
| `OTEL_TRACES_EXPORTER`, `OTEL_EXPORTER_OTLP_ENDPOINT` | To send {ellmer}'s traces to a tracing service instead of a file, set the exporter to `http` and point the endpoint at the service |
| `OTEL_R_EMIT_SCOPES` | {shiny} and {httr2} can send spans too; set it to `ellmer` to keep only {ellmer}'s |

## Moving the audit log to Postgres

On Posit Connect a redeploy deletes the SQLite file, so use Postgres there. Only the SQL in `sql/audit-postgres.sql` has been tested on Postgres, not the R side, which needs these changes:

- Create the table once, as an admin, from the SQL file, and drop the SQLite `CREATE TABLE`, pragma and triggers from `audit_open()`.
- Connect as `trial_app` with {RPostgres}, and write `$1`, `$2`, … instead of `?`.
- Replace `BEGIN IMMEDIATE` with `BEGIN`, then `SELECT pg_advisory_xact_lock(4711)`: a lock Postgres holds until the transaction ends, so a second writer waits its turn.
- Quote the `user` column, a reserved word in Postgres.

## Self-hosting a model

In {ellmer} 0.5.0, `chat_ollama()` can't call tools while streaming, and {shinychat} streams every answer. Serve the model with vLLM, with tool calling turned on (`--enable-auto-tool-choice` and your model's `--tool-call-parser`), and connect with `chat_vllm()`, or with `chat_openai_compatible()` for other servers with an OpenAI-style API. Nobody has run this app against vLLM yet.

## What's here

| Path | What it does |
|---|---|
| `mcp/` | The MCP server: the same tools as the app, minus patient records, each call logged |
| `demo/part-5-client.R` | A second agent using the tools over MCP |
| `R/audit.R`, `R/budget.R`, `sql/` | The audit log and the token budget, from part 4 |
| `R/approval.R`, `R/escalate.R`, `R/numbers.R`, `evals/` | Approval, escalation, the numbers check and the evals, from part 3 |
| `app.R`, `R/ui.R`, `R/attachments.R`, `R/wrap.R`, `R/display.R` | The Shiny app, from part 2 |
| `R/data.R`, `R/tools.R`, `R/agent.R` | The data, the tools and the agent, from part 1 |
| `prompts/system.md` | The system prompt |
| `tests/` | Offline tests, including one that starts the MCP server and calls it |
