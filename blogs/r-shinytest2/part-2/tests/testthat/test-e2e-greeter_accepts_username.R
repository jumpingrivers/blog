# ./tests/testthat/test-e2e-greeter_accepts_username.R
test_that("the greeter app updates user's name on clicking the button", {
  # GIVEN: the app is open
  shiny_app = shinyGreeter::run()
  app = shinytest2::AppDriver$new(shiny_app, name = "greeter")
  app$set_window_size(width = 1619, height = 970)

  # WHEN: the user enters their name and clicks the "Greet" button
  app$set_inputs(name = "Jumping Rivers")
  app$click("greet")

  # THEN: a greeting is printed to the screen
  values = app$expect_values(output = "greeting", screenshot_args = FALSE)
})
