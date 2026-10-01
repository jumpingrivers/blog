test_that("only the safety population is loaded, by actual treatment", {
  data <- load_trial_data()
  expect_equal(nrow(data$subjects), 254)
  expect_setequal(unique(data$subjects$ACTARM), ARMS)
  # 12 subjects randomised to high dose received low dose: 72, not 84.
  expect_equal(sum(data$subjects$ACTARM == "Xanomeline High Dose"), 72)
  expect_equal(sum(data$subjects$ACTARM == "Xanomeline Low Dose"), 96)
})

test_that("only treatment-emergent events of safety-population subjects are loaded", {
  data <- load_trial_data()
  expect_equal(nrow(data$events), 1122)
  expect_true(all(data$events$USUBJID %in% data$subjects$USUBJID))
})
