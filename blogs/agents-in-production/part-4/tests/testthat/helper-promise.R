# Run the event loop until a promise settles, then return its value or
# re-throw its error.
wait_for <- function(promise, timeout = 5) {
  state <- new.env()
  state$done <- FALSE
  promises::then(
    promise,
    function(value) {
      state$value <- value
      state$done <- TRUE
    },
    function(error) {
      state$error <- error
      state$done <- TRUE
    }
  )
  deadline <- Sys.time() + timeout
  while (!state$done && Sys.time() < deadline) later::run_now(0.05)
  if (!state$done) stop("Promise did not settle within ", timeout, " seconds.")
  if (!is.null(state$error)) stop(state$error)
  state$value
}
