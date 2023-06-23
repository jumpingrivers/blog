library("shiny")
library("tidyverse")
library("glue")
options(shiny.launch.browser = .rs.invokeShinyWindowExternal)


ui = fluidPage(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
    tags$script(src = "fullscreen.js")
  ),
  titlePanel(title = "Texas housing dashboard"),
  sidebarPanel(selectInput(
    "city", "City", unique(txhousing$city), selectize = FALSE
  ),),
  mainPanel(
    tags$div(
      plotOutput("salesPlot", height = "100%"),
      "class" = "plot-container",
      "tabindex" = "0" 
    ),
    tags$div(
      plotOutput("volumePlot", height = "100%"),
      "class" = "plot-container",
      "tabindex" = "0" 
    ),
    tags$div(
      plotOutput("medianPlot", height = "100%"),
      "class" = "plot-container",
      "tabindex" = "0" 
    ),
    tags$div(
      plotOutput("listingsPlot", height = "100%"),
      "class" = "plot-container",
      "tabindex" = "0" 
    )
  )
)


server = function(input, output, session) {
  baseData = txhousing %>%
    mutate(
      volume = volume / 1000000,
      median = median / 1000,
      date = as.Date(glue("{year}-{month}-01"), "%Y-%m-%d")
    )
  
  data = reactive({
    baseData %>%
      filter(city == input$city)
  })
  
  dates = as.Date(c("2000-01-01", "2015-07-01"), "%Y-%m-%d")
  
  formatLabels = function(label) {
    str_pad(label, 6, pad = " ")
  }
  
  createPlot = function(data, yProp, yTitle) {
    ggplot(data) +
      geom_line(aes(x = date, y = .data[[yProp]])) +
      labs(x = "Date",
           y = yTitle) +
      scale_x_date(limits = dates,
                   expand = expansion(mult = c(0.025, 0))) +
      scale_y_continuous(
        labels = formatLabels,
        limits = c(0, NA),
        expand = expansion(mult = c(0, 0.025))
      ) +
      theme(
        text = element_text(size = 14, colour = "black"),
        axis.text = element_text(family = "mono", size = 12),
        panel.grid.minor.x = element_blank(),
        panel.grid.minor.y = element_blank()
      )
  }
  
  output$salesPlot = renderPlot({
    createPlot(data(), "sales", "Number of sales\n")
  })
  
  output$volumePlot = renderPlot({
    createPlot(data(), "volume", "Total value of sales\n(millions)")
  })
  
  output$medianPlot = renderPlot({
    createPlot(data(), "median", "Total value of sales\n(millions)")
  })
  
  output$listingsPlot = renderPlot({
    createPlot(data(), "listings", "Total active listings\n")
  })
}


shinyApp(ui = ui, server = server)
