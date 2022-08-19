#' Set up default logger
#'
#' Creates a rotating file log using json format, see
#' \link[logger]{appender_file} for details.
#'
#' @param dir directory path for logs
#' @export
setup_logger = function(dir = "./API_logs") {
  if (! dir.exists(dir)) dir.create(dir)
  f = normalizePath(path.expand(file.path(dir, "log")))
  logger::log_formatter(logger::formatter_json)
  logger::log_layout(layout_json_custom(
    fields = c(
    "time", "level", "ns", "ns_pkg_version", "r_version"
  )))
  logger::log_appender(logger::appender_tee(
    f, max_lines = 2000L, max_files = 20L
  ))
}

layout_json_custom = function(fields = c("time")) {
    force(fields)
    # structure to match the logger documented requirements
    # for custom layout functions
    structure(
      function(
        level, msg, namespace = NA_character_,
        .logcall = sys.call(), .topcall = sys.call(-1),
        .topenv = parent.frame()
      ) {
        json = logger::get_logger_meta_variables(
          log_level = level, namespace = namespace,
          .logcall = .logcall, .topcall = .topcall,
          .topenv = .topenv
        )
        # take the message data passed in by the 
        # formatter and convert back to a list
        data = jsonlite::fromJSON(msg)
        sapply(
          msg, function(msg) {
            # reformat the output
            jsonlite::toJSON(c(json[fields], data), auto_unbox = TRUE)
          }
        )
    }, generator = deparse(match.call()))
}