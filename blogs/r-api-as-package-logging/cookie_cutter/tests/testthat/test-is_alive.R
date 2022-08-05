test_that("is alive", {
  res = httr::GET(glue::glue("http://0.0.0.0:{port}/test/is_alive"))
  expect_equal(res$status_code, 200)
})
