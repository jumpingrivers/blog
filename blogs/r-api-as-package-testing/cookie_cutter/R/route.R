#' Get API Routes
#'
#' Convenience function.
#' @param path Additional path added to extdata/api/routes/path
#' @return character, a file path
#' @export
get_internal_routes = function(path = ".") {
  system.file(
    "extdata", "api", "routes", path,
    package = utils::packageName(),
    mustWork = TRUE
  )
}

add_default_route_names = function(routes, dir) {
  names = stringr::str_remove(routes, pattern = dir)
  names = stringr::str_remove(names, pattern = "\\.R$")
  names(routes) = names
  routes
}

#' Create named from files
#' 
#' For a given directory, create a named vector of files and endpoints
#' @param dir directory containing end points
#' @return a named vector of characters
#' @export
create_routes = function(dir) {
  routes = list.files(
    dir, recursive = TRUE,
    full.names = TRUE, pattern = "*\\.R$"
  )
  add_default_route_names(routes, dir)
}

ensure_slash = function(string) {
  has_slash = grepl("^/", string)
  if (has_slash) string else paste0("/", string)
}

add_plumber_definition = function(pr, endpoint, file, ...) {
  router = plumber::pr(file = file, ...)
  plumber::pr_mount(pr = pr,
                    path = endpoint,
                    router = router
  )
}

#' Generate APIs
#'
#' routes is typically created by create_routes
#' @param routes A list of files. Element names are the plumber endpoints
#' @param ... filters and/or envir args to pass to plumber::pr
#' @return A Plumber object
#' @export
generate_api = function(routes, ...) {
  endpoints = purrr::map_chr(names(routes), ensure_slash)
  purrr::reduce2(
    .x = endpoints, .y = routes,
    .f = add_plumber_definition, ...,
    .init =  plumber::pr(NULL)
  )
}
