# Show tool results as readable tables in the chat. The model still gets JSON.

md_table <- function(df) {
  if (nrow(df) == 0) return("_No rows._")
  cells <- vapply(df, as.character, character(nrow(df)))
  if (is.null(dim(cells))) cells <- matrix(cells, nrow = 1)
  c(
    paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(cells, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  )
}

result_markdown <- function(json) {
  # Not every tool returns JSON: part 3's escalate() returns a sentence.
  if (!isTRUE(jsonlite::validate(json))) return(as.character(json))
  x <- jsonlite::fromJSON(json)
  if (is.data.frame(x)) return(paste(md_table(x), collapse = "\n"))
  lines <- character()
  for (name in names(x)) {
    value <- x[[name]]
    if (is.data.frame(value)) {
      lines <- c(lines, "", md_table(value), "")
    } else if (is.list(value)) {
      lines <- c(lines, paste0("- **", names(value), "**: ", unlist(value)))
    } else {
      lines <- c(lines, paste0("- **", name, "**: ", value))
    }
  }
  paste(lines, collapse = "\n")
}

with_display <- function(tools) {
  lapply(tools, function(tool) {
    wrap_tool(tool, function(run, args) {
      value <- run()
      # The display is for people. If it can't be built, the model still
      # gets its answer.
      markdown <- tryCatch(result_markdown(value), error = function(e) NULL)
      if (is.null(markdown)) return(value)
      ellmer::ContentToolResult(
        value = value,
        extra = list(display = shinychat::tool_result_display(markdown = markdown))
      )
    })
  })
}
