profile_request <- ellmer::ContentToolRequest(
  id = "1", name = "subject_profile", arguments = list(usubjid = "01-701-1015")
)

test_that("only reviewers can view patients", {
  expect_true(can_view_patients(c("analysts", "trial-reviewers")))
  expect_false(can_view_patients(NULL))
  expect_false(can_view_patients("analysts"))
})

test_that("tools other than subject_profile run without asking", {
  asked <- FALSE
  callback <- approval_callback("analysts", function(usubjid) {
    asked <<- TRUE
    promises::promise_resolve(TRUE)
  })
  request <- ellmer::ContentToolRequest(id = "2", name = "count_subjects", arguments = list())
  expect_null(wait_for(callback(request)))
  expect_false(asked)
})

test_that("a user outside the reviewer group is rejected without being asked", {
  asked <- FALSE
  callback <- approval_callback("analysts", function(usubjid) {
    asked <<- TRUE
    promises::promise_resolve(TRUE)
  })
  expect_error(wait_for(callback(profile_request)), class = "ellmer_tool_reject")
  expect_false(asked)
})

test_that("a reviewer's decision decides the call", {
  allow <- approval_callback("trial-reviewers", function(usubjid) promises::promise_resolve(TRUE))
  decline <- approval_callback("trial-reviewers", function(usubjid) promises::promise_resolve(FALSE))
  expect_null(wait_for(allow(profile_request)))
  expect_error(wait_for(decline(profile_request)), "declined", class = "ellmer_tool_reject")
})

test_that("TRIAL_DEV_GROUPS stands in locally but is ignored on Connect", {
  withr::local_envvar(TRIAL_DEV_GROUPS = "trial-reviewers", RSTUDIO_PRODUCT = "", POSIT_PRODUCT = "")
  expect_equal(user_groups(list(groups = NULL)), "trial-reviewers")
  withr::local_envvar(RSTUDIO_PRODUCT = "CONNECT")
  expect_equal(user_groups(list(groups = NULL)), character())
})

test_that("Connect is recognised by POSIT_PRODUCT, which replaces RSTUDIO_PRODUCT", {
  withr::local_envvar(TRIAL_DEV_GROUPS = "trial-reviewers", RSTUDIO_PRODUCT = "", POSIT_PRODUCT = "CONNECT")
  expect_equal(user_groups(list(groups = NULL)), character())
})

test_that("approval questions are asked one at a time", {
  # Shiny has one modal slot: a second dialog would replace the first and
  # leave its promise waiting forever.
  open <- 0
  most_open <- 0
  ask <- function(usubjid) {
    open <<- open + 1
    most_open <<- max(most_open, open)
    promises::promise(function(resolve, reject) {
      later::later(function() {
        open <<- open - 1
        resolve(usubjid)
      }, 0.1)
    })
  }
  serial <- one_at_a_time(ask)
  both <- promises::promise_all(serial("01-701-1015"), serial("01-701-1023"))
  expect_equal(wait_for(both), list("01-701-1015", "01-701-1023"))
  expect_equal(most_open, 1)
})

test_that("a failed question doesn't block the next one", {
  calls <- 0
  ask <- function(usubjid) {
    calls <<- calls + 1
    if (calls == 1) promises::promise_reject(simpleError("dialog closed")) else promises::promise_resolve(TRUE)
  }
  serial <- one_at_a_time(ask)
  first <- serial("01-701-1015")
  second <- serial("01-701-1023")
  expect_error(wait_for(first), "dialog closed")
  expect_true(wait_for(second))
})

test_that("every approval decision is logged, allowed or not", {
  events <- list()
  log <- function(event, tool = NULL, input = NULL, output = NULL) {
    events[[length(events) + 1]] <<- list(event = event, tool = tool, input = input)
  }
  no_access <- approval_callback("analysts", function(usubjid) promises::promise_resolve(TRUE), log)
  declined <- approval_callback("trial-reviewers", function(usubjid) promises::promise_resolve(FALSE), log)
  granted <- approval_callback("trial-reviewers", function(usubjid) promises::promise_resolve(TRUE), log)
  expect_error(wait_for(no_access(profile_request)), class = "ellmer_tool_reject")
  expect_error(wait_for(declined(profile_request)), class = "ellmer_tool_reject")
  wait_for(granted(profile_request))
  expect_equal(
    vapply(events, function(e) e$event, character(1)),
    c("approval_refused", "approval_declined", "approval_granted")
  )
  expect_equal(events[[3]]$tool, "subject_profile")
  expect_equal(events[[3]]$input$usubjid, "01-701-1015")
})
