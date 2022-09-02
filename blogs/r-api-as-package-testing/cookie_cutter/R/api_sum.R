is_array = function(parsed_json) {
  is.null(names(parsed_json))
}

#' Sum
#' 
#' Sum numeric contents of json objects
#' 
#' @param req rook request object, received by function via plumber route
#' @export
api_sum = function(req) {
  parsed_json = jsonlite::fromJSON(req$postBody)
  return (my_sum(parsed_json))
}

sum_list = function(l) {
  purrr::keep(l, is.numeric) |> purrr::reduce(`+`, .init=0)
}

my_sum = function(x) {
  if (is_array(x)) {
    if(is.list(x)) {
      purrr::map(x, sum_list)
    } else {
      sum(x)
    }
  } else {
    sum_list(x)
  }
}