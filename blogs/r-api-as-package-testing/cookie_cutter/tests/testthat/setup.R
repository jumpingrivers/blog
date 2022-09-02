# test/testthat/setup.R

## run before any tests
# pick a random available port to serve your app locally
port = httpuv::randomPort()

# start a background R process that launches an instance of the API
# serving on that random port
running_api = callr::r_bg(
  function(port) {
    dir = cookieCutter::get_internal_routes()
    routes = cookieCutter::create_routes(dir)
    api = cookieCutter::generate_api(routes)
    api$run(port = port, host = "0.0.0.0")
  }, list(port = port)
)

Sys.sleep(2)
## run after all tests
withr::defer(running_api$kill(), testthat::teardown_env())
