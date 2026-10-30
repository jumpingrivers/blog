# Part 1: the agent in the console. Needs GEMINI_API_KEY or GOOGLE_API_KEY.
for (file in c("R/data.R", "R/tools.R", "R/agent.R")) source(file)

# Without tools, the model can only guess.
bare <- ellmer::chat_google_gemini()
bare$chat("In CDISC pilot study 01, how many subjects on high-dose xanomeline had pruritus?", echo = "output")

# With tools, R does the counting.
chat <- make_agent()
chat$chat("Which adverse events were most common on the high dose, compared with placebo?", echo = "all")
chat$chat("How many subjects had a serious adverse event, and on which arms?", echo = "all")
print(chat$get_cost())
