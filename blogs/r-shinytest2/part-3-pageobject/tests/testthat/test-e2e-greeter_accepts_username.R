# ./tests/testthat/test-e2e-greeter_accepts_username.R
GreeterApp = R6::R6Class(
  "GreeterApp",
  inherit = shinytest2::AppDriver,
  public = list(
    width = 1619,
    height = 970,
    initialize = function(name) {
      shiny_app = shinyGreeter::run()
      super$initialize(shiny_app, name = name)
      self$set_window_size(width = self$width, height = self$height)
    },
    enter_username = function(username) {
      self$set_inputs(name = username)
      self$click("greet")

      invisible(self)
    }
  )
)

test_that("the greeter app updates user's name on clicking the button", {
  # GIVEN: the app is open
  app = GreeterApp$new("greeter")

  # WHEN: the user enters their name and clicks the "Greet" button
  app$enter_username("Jumping Rivers")

  # THEN: a greeting is printed to the screen
  message = app$get_value(output = "greeting")
  expect_equal(message, "Hello Jumping Rivers!")
})

test_that("the greeter app prints a Spanish greeting to the user", {
  # GIVEN: the app is open
  app = GreeterApp$new("spanish_greeter")

  # WHEN: the user enters their name and clicks the "Greet" button
  app$enter_username("Jumping Rivers")

  # THEN: a Spanish greeting is printed to the screen
  message = app$get_value(output = "spanish_greeting")
  expect_equal(message, "Hola Jumping Rivers!")
})
