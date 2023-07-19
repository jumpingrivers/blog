ufo_sightings = readr::read_csv("ufo_sightings.csv")

states = unique(ufo_sightings$state_name)[1:3]
years = unique(ufo_sightings$year)[1]

params = tidyr::crossing(
  state = states,
  year = years
)

purrr::walk2(params$year, params$state, ~quarto::quarto_render(
  input = "slides.qmd",
  execute_params = list("year" = .x,
                        "state" = .y),
  output_file = glue::glue("{.y}_{.x}.html")
))
