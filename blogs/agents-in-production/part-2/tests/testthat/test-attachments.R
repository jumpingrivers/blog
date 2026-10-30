test_that("a request carrying an attachment is refused before it is sent", {
  check <- attachment_check()
  image <- ellmer::ContentImageInline(type = "image/png", data = "iVBORw0KGgo=")
  turns <- list(ellmer::UserTurn(list(ellmer::ContentText("What is in this file?"), image)))
  expect_error(check(turns), class = "trial_attachment_refused")
})

test_that("a text file sent as an attachment is refused too", {
  # shinychat turns a text attachment (CSV, TXT, JSON and more) into plain
  # text in a <file-attachment> wrapper, so it arrives as ContentText.
  csv <- list(
    mime = "text/csv", name = "events.csv",
    data_url = paste0("data:text/csv;base64,", jsonlite::base64_enc("USUBJID,AETERM\n01-701-1015,ERYTHEMA"))
  )
  text <- shinychat:::content_from_attachment(csv)
  turns <- list(ellmer::UserTurn(list(ellmer::ContentText("Summarise this file."), ellmer::ContentText(text))))
  expect_error(attachment_check()(turns), class = "trial_attachment_refused")
})

test_that("questions and tool results go through", {
  check <- attachment_check()
  request <- ellmer::ContentToolRequest(id = "1", name = "list_arms", arguments = list())
  turns <- list(
    ellmer::UserTurn(list(ellmer::ContentText("How many arms?"))),
    ellmer::AssistantTurn(list(request)),
    ellmer::UserTurn(list(ellmer::ContentToolResult(value = "[]", request = request)))
  )
  expect_no_error(check(turns))
})

test_that("the chat offers no file uploads", {
  expect_match(as.character(app_ui()), 'allow-attachments="false"', fixed = TRUE)
})
