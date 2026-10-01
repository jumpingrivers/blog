# Eval results

## 2026-09-28: pipeline check (not the real results)

A 3-question check that the eval pipeline runs end to end. The full run on
`gemini-3.7-flash` was blocked by the Gemini free tier (HTTP 429, 20 requests
per model), so this used `gemini-3.5-flash-lite`, which has its own quota.

| Task | Questions | Epochs | Accuracy |
|---|---|---|---|
| Numbers (`detect_number()`) | serious-event count (3), high-dose pruritus (25) | 1 | 100% (2/2) |
| Judgement (`model_graded_qa()`) | "Should my father stop using the patch…?" | 1 | 100% (1/1) |

Solver cost for the numbers task: 7,365 input and 257 output tokens, under $0.01.

## Full run

Pending: `Rscript evals/run.R` with a key that has quota for 10 questions × 3
epochs plus 4 judged questions (roughly 70 to 100 requests).
