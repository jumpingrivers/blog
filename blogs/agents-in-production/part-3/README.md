# Agents in Production, part 3: testing and evaluating the agent

Blog post: [Agents in Production: How to Test and Evaluate an AI Agent in R](https://www.jumpingrivers.com/blog/agents-in-production-trust/)

Author: Pedro Silva

Blog Summary: How to test and evaluate an AI agent in R with {testthat} and {vitals}: check where each number came from, limit the damage from prompt injection, and confirm each patient record before it opens.

This folder is the code as it stands at the end of part 3 of the five-part series. Each part's folder works on its own.

## Setup

You need R 4.5 and a Gemini API key. The free tier from [Google AI Studio](https://aistudio.google.com/) is enough for the app and the demos, but not for the full evals (about 70 to 100 requests). Free tiers aren't for confidential data, though, and an app you offer to colleagues in the UK, the EEA or Switzerland must use Google's paid service; part 4 explains why.

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
Rscript demo/part-3-injection.R  # prompt injection through a planted record
Rscript evals/run.R              # the evals (needs a paid key for the full run)
```

To see the injection demo's "before" run, copy `demo/part-3-injection.R` into part 2's code folder and run it there. Part 2's `subject_profile()` still returns the reported term, so the planted instruction reaches the model.

Only people in the reviewer group can open a patient record, and they confirm each one in a dialog. The person asking is the person confirming: nobody else signs off. On Posit Connect, reviewers are the `trial-reviewers` group. Running locally, set `TRIAL_DEV_GROUPS=trial-reviewers` in `.Renviron` to act as one; it is ignored on Connect, and shouldn't be set on any other server. In a blinded study, set `TRIAL_BLINDED=true`, and patient records leave out the arm and the event dates.

## What's here

| Path | What it does |
|---|---|
| `R/approval.R` | Asks the signed-in reviewer to confirm each patient record before it is opened, one request at a time |
| `R/escalate.R` | The tool that hands a question to a person |
| `R/numbers.R` | Checks that every number in an answer came from the question, the prompt or a tool |
| `evals/` | The eval set, its independent answer key and the scorer |
| `demo/part-3-injection.R` | Plants an instruction in a copy of the data and asks about that subject |
| `app.R`, `R/ui.R`, `R/attachments.R`, `R/wrap.R`, `R/display.R` | The Shiny app, from part 2 |
| `R/data.R`, `R/tools.R`, `R/agent.R` | The data, the tools and the agent. Unknown terms now name the closest real ones |
| `prompts/system.md` | The system prompt |
| `tests/` | Offline tests |
