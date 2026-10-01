test_that("the page only loads images from its own server", {
  # The model's answers are Markdown, and an injected image would make the
  # browser fetch an address the attacker chose, with data in it.
  head <- htmltools::renderTags(app_ui())$head
  policy <- regmatches(head, regexpr('http-equiv="Content-Security-Policy" content="[^"]*"', head))
  expect_length(policy, 1)
  directives <- strsplit(gsub("&#39;", "'", sub('.*content="([^"]*)"', "\\1", policy)), ";")[[1]]
  img_src <- grep("^\\s*img-src\\s", directives, value = TRUE)
  expect_length(img_src, 1)
  sources <- strsplit(trimws(sub("^\\s*img-src\\s+", "", img_src)), "\\s+")[[1]]
  expect_setequal(sources, c("'self'", "data:"))
})
