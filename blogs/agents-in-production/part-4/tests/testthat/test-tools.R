data <- load_trial_data()
from_json <- function(x) jsonlite::fromJSON(x)

test_that("list_arms counts the safety population per arm", {
  arms <- from_json(list_arms(data))
  expect_equal(arms$subjects[arms$arm == "Placebo"], 86)
  expect_equal(arms$subjects[arms$arm == "Xanomeline High Dose"], 72)
  expect_equal(arms$subjects[arms$arm == "Xanomeline Low Dose"], 96)
  expect_equal(sum(arms$subjects), 254)
})

test_that("count_subjects uses the arm as the denominator", {
  result <- from_json(count_subjects(data, arm = "Xanomeline High Dose", term = "PRURITUS"))
  expect_equal(result$subjects_with_event, 25)
  expect_equal(result$subjects_in_arm, 72)
  expect_equal(result$percent, 34.7)
})

test_that("count_subjects counts serious events across all arms", {
  result <- from_json(count_subjects(data, serious_only = TRUE))
  expect_equal(result$subjects_with_event, 3)
  expect_equal(result$arm, "All arms")
  expect_equal(result$subjects_in_arm, 254)
})

test_that("a known term with no events in the arm is a real zero", {
  result <- from_json(count_subjects(data, arm = "Placebo", term = "SYNCOPE"))
  expect_equal(result$subjects_with_event, 0)
})

test_that("terms match regardless of case and spaces", {
  result <- from_json(count_subjects(data, arm = "Placebo", term = " pruritus "))
  expect_equal(result$subjects_with_event, 8)
})

test_that("an unknown term is an error that says how to recover, not a zero", {
  expect_error(count_subjects(data, term = "itching"), "Unknown preferred term\\..*ae_summary")
  expect_error(count_subjects(data, body_system = "skin"), "Unknown body system")
})

test_that("an unknown arm is an error that lists the arms", {
  expect_error(count_subjects(data, arm = "High Dose"), "Unknown arm\\..*Xanomeline High Dose")
})

test_that("ae_summary ranks events by subjects with ties broken by name", {
  result <- from_json(ae_summary(data, arm = "Xanomeline High Dose", top_n = 3))
  expect_equal(result$rows$event, c("PRURITUS", "APPLICATION SITE PRURITUS", "APPLICATION SITE ERYTHEMA"))
  expect_equal(result$rows$subjects, c(25, 21, 14))
})

test_that("ae_summary can group by body system", {
  result <- from_json(ae_summary(data, arm = "Xanomeline High Dose", by = "body_system", top_n = 1))
  expect_equal(result$rows$event, "SKIN AND SUBCUTANEOUS TISSUE DISORDERS")
  expect_equal(result$rows$subjects, 39)
})

test_that("ae_summary keeps top_n between 1 and 50", {
  expect_equal(nrow(from_json(ae_summary(data, top_n = 500))$rows), 50)
  expect_equal(nrow(from_json(ae_summary(data, top_n = NULL))$rows), 10)
})

test_that("subject_profile returns one subject's record", {
  result <- from_json(subject_profile(data, "01-701-1015"))
  expect_equal(result$subject$ACTARM, "Placebo")
  expect_equal(nrow(result$events), 3)
})

test_that("subject_profile trims spaces but rejects malformed IDs", {
  expect_no_error(subject_profile(data, " 01-701-1015 "))
  expect_error(subject_profile(data, "1015"), "look like 01-701-1015")
})

test_that("subject_profile refuses screen failures and unknown subjects", {
  expect_error(subject_profile(data, "01-701-1057"), "not in the safety population")
  expect_error(subject_profile(data, "01-701-9999"), "not in the safety population")
})

test_that("trial_tools defines the four tools with matching arguments", {
  tools <- trial_tools(data)
  expect_equal(
    vapply(tools, function(tool) tool@name, character(1)),
    c("list_arms", "count_subjects", "ae_summary", "subject_profile")
  )
  count <- tools[[2]]
  expect_equal(from_json(count(arm = "Placebo", term = "PRURITUS"))$subjects_with_event, 8)
})

test_that("subject_profile shows the model coded terms only", {
  result <- from_json(subject_profile(data, "01-701-1015"))
  expect_false("reported_term" %in% names(result$events))
  expect_true("preferred_term" %in% names(result$events))
})

test_that("arguments must be single values of the right type, never silently reread", {
  # Without these checks: serious_only = "true" counted every event (217, not 3),
  # and two terms counted only the last one.
  expect_error(count_subjects(data, serious_only = "true"), "`serious_only` must be true or false")
  expect_error(count_subjects(data, serious_only = 1), "`serious_only` must be true or false")
  expect_error(count_subjects(data, term = c("RASH", "PRURITUS")), "`term` must be a single piece of text")
  expect_error(count_subjects(data, arm = c("Placebo", "Xanomeline Low Dose")), "`arm` must be a single piece of text")
  expect_error(ae_summary(data, top_n = c(1, 2)), "`top_n` must be a single number")
  expect_error(subject_profile(data, c("01-701-1015", "01-701-1023")), "`usubjid` must be a single piece of text")
})

test_that("results say which filters were applied", {
  result <- from_json(count_subjects(data, arm = "Placebo", serious_only = TRUE, term = "syncope"))
  expect_equal(result$filters$term, "SYNCOPE")
  expect_true(result$filters$serious_only)
  expect_equal(result$filters$body_system, "any")
  summary <- from_json(ae_summary(data, serious_only = TRUE))
  expect_true(summary$serious_only)
})

test_that("an unknown term's error names the closest terms in the trial", {
  # ae_summary shows at most 50 of the 230 terms, so "call ae_summary" alone
  # can't lead the model to a rare term like one of the serious events.
  expect_error(
    count_subjects(data, term = "seizure"),
    "Closest in this trial: .*PARTIAL SEIZURES WITH SECONDARY GENERALISATION"
  )
})

test_that("the closest-term hint only names terms that share a word with the request", {
  # A spelling match suggested VOMITING for "itching" and missed the skin
  # body system for "skin disorders". A model that follows the hint would
  # count the wrong event.
  error <- tryCatch(count_subjects(data, term = "itching"), error = conditionMessage)
  expect_no_match(error, "Closest")
  expect_error(count_subjects(data, term = "dizzy"), "Closest in this trial: DIZZINESS")
  expect_error(
    count_subjects(data, body_system = "skin disorders"),
    "Closest in this trial: SKIN AND SUBCUTANEOUS TISSUE DISORDERS", fixed = TRUE
  )
})

test_that("errors don't repeat the subject ID, since tool errors reach the traces", {
  error <- tryCatch(subject_profile(data, "01-701-9999"), error = conditionMessage)
  expect_match(error, "not in the safety population")
  expect_no_match(error, "01-701-9999", fixed = TRUE)
})

test_that("a term used in the trial but never treatment-emergent is a real zero", {
  result <- from_json(count_subjects(data, term = "GLAUCOMA"))
  expect_equal(result$subjects_with_event, 0)
})

test_that("tool errors don't repeat what the model sent, since they reach the traces", {
  # A term or arm the model sends can carry the user's own words.
  errors <- c(
    tryCatch(count_subjects(data, term = "my itchy rash"), error = conditionMessage),
    tryCatch(count_subjects(data, body_system = "my skin"), error = conditionMessage),
    tryCatch(count_subjects(data, arm = "the one I was on"), error = conditionMessage)
  )
  for (error in errors) expect_no_match(error, "my itchy rash|my skin|the one I was on")
})

test_that("tool errors point to what can help without giving the model orders", {
  # From part 3 on, the system prompt says to ignore instructions in tool results.
  errors <- c(
    tryCatch(count_subjects(data, term = "itching"), error = conditionMessage),
    tryCatch(count_subjects(data, body_system = "skin"), error = conditionMessage),
    tryCatch(count_subjects(data, arm = "High Dose"), error = conditionMessage)
  )
  for (error in errors) expect_no_match(error, "(?i)\\b(call|use)\\b", perl = TRUE)
  expect_match(errors[[1]], "ae_summary")
})

test_that("a blinded patient record leaves out the arm and the dates", {
  # In a blinded study, the arm unblinds the patient, and dates with age, sex
  # and race can help identify them.
  result <- from_json(subject_profile(data, "01-701-1015", blinded = TRUE))
  expect_false("ACTARM" %in% names(result$subject))
  expect_false("start" %in% names(result$events))
  expect_equal(nrow(result$events), 3)
})

test_that("trial_tools passes blinding on to the patient record", {
  record <- from_json(trial_tools(data, blinded = TRUE)[[4]](usubjid = "01-701-1015"))
  expect_false("ACTARM" %in% names(record$subject))
  unblinded <- from_json(trial_tools(data)[[4]](usubjid = "01-701-1015"))
  expect_equal(unblinded$subject$ACTARM, "Placebo")
})
