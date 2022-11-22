# ./tests/testthat/test-e2e-greeter_accepts_username.R
initialise_test_app = function(name) {
  shiny_app = run()
  app = shinytest2::AppDriver$new(shiny_app, name = name)
  app$set_window_size(width = 1619, height = 970)

  app
}

enter_username = function(app, username) {
  app$set_inputs(name = username)
  app$click("greet")

  # return the app object, so that you can pipe together the actions
  invisible(app)
}

test_that("the greeter app updates user's name on clicking the button", {
  # GIVEN: the app is open
  app = initialise_test_app("greeter")

  # WHEN: the user enters their name and clicks the "Greet" button
  enter_username(app, "Jumping Rivers")

  # THEN: a greeting is printed to the screen
  message = app$get_value(output = "greeting")
  expect_equal(message, "Hello Jumping Rivers!")
})

test_that("the greeter app prints a Spanish greeting to the user", {
  # GIVEN: the app is open
  app = initialise_test_app("spanish_greeter")

  # WHEN: the user enters their name and clicks the "Greet" button
  enter_username(app, "Jumping Rivers")

  # THEN: a Spanish greeting is printed to the screen
  message = app$get_value(output = "spanish_greeting")
  expect_equal(message, "Hola Jumping Rivers!")
})
