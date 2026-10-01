# Agents in Production, part 2: a Shiny chat app

Blog post: [Agents in Production: Build an AI Chat App with Shiny and {shinychat}](https://www.jumpingrivers.com/blog/agents-in-production-shiny/)

Author: Pedro Silva

Blog Summary: Turn an {ellmer} AI agent into a Shiny chat app with {shinychat}: streaming answers, visible tool calls, one conversation per user, no file uploads, and deployment to Posit Connect.

This folder is the code as it stands at the end of part 2 of the five-part series. Each part's folder works on its own.

## Setup

You need R 4.5 and a Gemini API key. The free tier from [Google AI Studio](https://aistudio.google.com/) is enough to try the app. Free tiers aren't for confidential data, though, and an app you offer to colleagues in the UK, the EEA or Switzerland must use Google's paid service; part 4 explains why.

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
Rscript demo/part-1.R            # part 1's console demo
```

The test that starts the app in a real browser is opt-in: set `TRIAL_BROWSER_TESTS=true` to run it.

To deploy the app to Posit Connect, see the post: `rsconnect::deployApp()` with the files it lists, and `envVars = "GEMINI_API_KEY"` to copy the key into Connect's **Vars** panel.

Before your first deploy, register your Connect account once: run `rsconnect::addServer()` with your server's address, then `rsconnect::connectUser()`. Or use RStudio's Publishing settings.

## What's here

| Path | What it does |
|---|---|
| `app.R` | The Shiny app: one chat client per session |
| `R/ui.R` | The page: a greeting, and no file uploads |
| `R/attachments.R` | Refuses file attachments sent to the model (images, PDFs and text files such as CSV), even from a crafted request |
| `R/wrap.R`, `R/display.R` | Show each tool's result as a readable table in the chat |
| `R/data.R`, `R/tools.R`, `R/agent.R` | The data, the four tools and the agent, from part 1 |
| `prompts/system.md` | The system prompt |
| `demo/` | Part 1's console demo and the transcripts quoted in the posts |
| `tests/` | Offline tests, including one that two sessions never share a chat client |
