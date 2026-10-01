# Agents in Production, part 4: audit trails, costs and models

Blog post: [Agents in Production: Audit Trails and Cost Control for AI Agents in R](https://www.jumpingrivers.com/blog/agents-in-production-running/)

Author: Pedro Silva

Blog Summary: Run an AI agent in production with R: a hash-chained audit log built on ALCOA principles, OpenTelemetry tracing that leaves message content out, a token budget, caching, and choosing a model with evals.

This folder is the code as it stands at the end of part 4 of the five-part series. Each part's folder works on its own.

## Setup

You need R 4.5 and a Gemini API key. The free tier from [Google AI Studio](https://aistudio.google.com/) is enough for the app and the demos, but not for the evals or the model comparison. Free tiers aren't for confidential data, and an app you offer to colleagues in the UK, the EEA or Switzerland must use Google's paid service; the post explains why.

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
Rscript tests/run.R                # offline tests, no API calls
Rscript -e "shiny::runApp()"       # the app, with its audit log in audit.sqlite
Rscript evals/run.R                # part 3's evals (needs a paid key)
Rscript evals/compare-models.R     # the same evals on two models (needs a paid key)
```

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
| `R/audit.R` | The append-only, hash-chained audit log, and the wrapper that logs every tool call before it runs. Keep a copy of `audit_head()` somewhere the app can't write, and check against it with `audit_verify(con, head)` |
| `R/budget.R` | The per-session token budget |
| `sql/audit-postgres.sql` | The audit table for Postgres, where the app's role can only add and read rows |
| `evals/compare-models.R` | Compares accuracy, time and cost across two models |
| `app.R` | The Shiny app, now logging every session, question, tool call and answer |
| `R/approval.R`, `R/escalate.R`, `R/numbers.R`, `evals/` | Approval, escalation, the numbers check and the evals, from part 3 |
| `R/ui.R`, `R/attachments.R`, `R/wrap.R`, `R/display.R` | The page and the chat display, from part 2 |
| `R/data.R`, `R/tools.R`, `R/agent.R` | The data, the tools and the agent, from part 1 |
| `prompts/system.md` | The system prompt |
| `tests/` | Offline tests |
