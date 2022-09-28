library("shiny")
library("waiter")
library("leaflet")
library("lubridate")
library("glue")
library("tibble")
library("stringr")
library("purrr")
library("httr")

get_10_positions = function(timestamps) {
  collapsed_timestamps = paste0(timestamps, collapse = ",")
  res = httr::GET(glue("https://api.wheretheiss.at/v1/satellites/25544/positions?timestamps={collapsed_timestamps}"))
  content = httr::content(res)
  iss_locations = tibble(
    iss_lats = as.numeric(purrr::map_chr(content, ~.x$latitude)),
    iss_longs = as.numeric(purrr::map_chr(content, ~.x$longitude))
  )
  return(iss_locations)
}

get_timestamps = function() {
  now_seconds = round(unclass(now())[[1]])
  timestamps = seq(now_seconds - 600, now_seconds, 30)
  split(timestamps, ceiling(seq_along(timestamps)/10))
}

ui = fluidPage(
  useWaiter(),
  titlePanel("{waiter}"),
  h2("Locations of the ISS in the last 10 mins"),
  wellPanel(
    leafletOutput("iss_location")
  ),
  fluidRow(
    column(
      width = 12,
      actionButton(
        "refresh",
        "Refresh App",
        icon = icon("sync")
      ),
      align = "center"
    )

  )
)

server = function(input, output, session) {

  observeEvent(input$refresh, {
    waiter_show(
      html = HTML(paste(spin_fading_circles(),
                        br(),
                        h4("Retrieving data from API...")))
    )

    all_positions = map_dfr(get_timestamps(), get_10_positions)
    waiter_show(
      html = HTML(paste(spin_fading_circles(),
                               br(),
                               h4("Creating map...")))
    )

    output$iss_location = renderLeaflet({
      m = leaflet(all_positions)
      m = addTiles(m)
      m = addMarkers(m, lng = ~iss_longs, lat = ~iss_lats,
                     popup = "Position of the International Space Station")
    })
    waiter_hide()
  }, ignoreNULL = FALSE
  )
}



shinyApp(ui, server)
