# Trial data: the safety population of CDISC pilot study 01 and its
# treatment-emergent adverse events, as packaged in {pharmaverseadam}.

ARMS <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")

load_trial_data <- function() {
  subjects <- pharmaverseadam::adsl |>
    dplyr::filter(SAFFL == "Y") |>
    dplyr::select(USUBJID, ACTARM, AGE, SEX, RACE)
  events <- pharmaverseadam::adae |>
    dplyr::filter(TRTEMFL %in% "Y", USUBJID %in% subjects$USUBJID) |>
    dplyr::select(USUBJID, ACTARM, AEDECOD, AETERM, AEBODSYS, AESER, AESEV, ASTDT)
  list(
    subjects = subjects,
    events = events,
    # Every term and body system recorded in the trial, including the few
    # never treatment-emergent, so asking about them gives a real zero.
    terms = sort(unique(pharmaverseadam::adae$AEDECOD)),
    body_systems = sort(unique(pharmaverseadam::adae$AEBODSYS))
  )
}
