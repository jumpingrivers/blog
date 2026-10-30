# A tool that hands a question to a person instead of guessing.

escalate_tool <- function(on_escalate = function(reason) invisible()) {
  ellmer::tool(
    function(reason) {
      on_escalate(reason)
      "Handed to the study team. A person will follow up."
    },
    name = "escalate",
    description = paste(
      "Hand the question to a person on the study team. Use it for requests for",
      "medical advice, questions outside this trial's safety data, or questions",
      "the other tools can't answer."
    ),
    arguments = list(reason = ellmer::type_string("One sentence on why a person is needed.")),
    annotations = ellmer::tool_annotations(title = "Handing over to the study team")
  )
}
