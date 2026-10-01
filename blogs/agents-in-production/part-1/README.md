# Agents in Production, part 1: your first AI agent

Blog post: [Agents in Production: Build Your First AI Agent in R with {ellmer}](https://www.jumpingrivers.com/blog/agents-in-production-first-agent/)

Author: Pedro Silva

Blog Summary: Build your first AI agent in R with {ellmer} tool calling: a clinical trial assistant where the model picks the tools and R does the counting.

This folder is the code as it stands at the end of part 1 of the five-part series. Each part's folder works on its own.

## Setup

You need R 4.5 and a Gemini API key. The free tier from [Google AI Studio](https://aistudio.google.com/) is enough for the demo. Free tiers aren't for confidential data, though; part 4 explains why.

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
- **On Windows, `Rscript` usually isn't on the PATH.** In PowerShell, give its full path, such as `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" tests/run.R`, or run each script from the R console with `source()`.
- **Without {renv}**, you get newer packages than we tested, and `tests/testthat/test-setup.R`, which checks the pinned versions, fails.

## Run

```sh
Rscript tests/run.R      # offline tests, no API calls
Rscript demo/part-1.R    # asks the questions from the post
```

## What's here

| Path | What it does |
|---|---|
| `R/data.R` | Loads the safety population and the treatment-emergent adverse events from {pharmaverseadam} |
| `R/tools.R` | The four tools. Each returns JSON and rejects anything it doesn't recognise |
| `R/agent.R` | `make_agent()`: the chat, its system prompt and its tools |
| `prompts/system.md` | The system prompt |
| `demo/part-1.R` | The console demo from the post |
| `demo/output/` | The transcripts quoted in the post |
| `tests/` | Offline tests: every count is checked against numbers worked out by hand |
