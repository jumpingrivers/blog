purrr::pwalk(tibble::tibble(
  file = sort(list.files(test_path("example_data"), full.names = TRUE)),
  length = c(2, 1, 1),
  sums = list(c(3,3), 3, 3)
), function(file, length, sums){

  test_case = test_case_json(file)

  test_that("succesful api response", {
    skip_dead_api()
    headers = httr::add_headers(
      Accept = "application/json",
      "Content-Type" = "application/json"
    )
    response = api_post("/example/sum", body = test_case, headers = headers)
    expect_equal(response$status_code, 200)
  })

  test_that("successful api func", {
    input = as_fake_post(test_case)
    res = api_sum(input)
    expect_length(res, length)
  })

  test_that("successful sum", {
    input = jsonlite::fromJSON(test_case)
    res = my_sum(input)
    expect_equal(res, sums)
  })
})
