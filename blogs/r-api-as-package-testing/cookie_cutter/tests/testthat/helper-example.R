# skip other tests if api is not alive
skip_dead_api = function() {
  testthat::skip_if_not(running_api$is_alive(), "Api not started")
}

endpoint = function(str) {
  glue::glue("http://0.0.0.0:{port}{str}")
}

api_post = function(url, ...) {
  httr::POST(endpoint(url), ...)
}

test_case_json = function(path) {
  file = testthat::test_path(path)
  obj = readLines(file)
  paste(obj, collapse = "")
}

as_fake_post = function(obj) {
  req = new.env()
  req$HTTP_CONTENT_TYPE = "application/json"
  req$postBody = obj
  req
}

