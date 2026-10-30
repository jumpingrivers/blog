test_that("the eval answer key matches the numbers checked by hand", {
  source(test_path("..", "..", "evals", "dataset.R"), local = TRUE)
  numbers <- build_number_set()
  expect_equal(numbers$target, c("254", "86", "3", "25", "8", "23", "13.9", "5", "0", "87.5"))
  expect_equal(nrow(build_judgement_set()), 4)
})
