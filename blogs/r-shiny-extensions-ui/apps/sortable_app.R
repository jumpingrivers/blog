library("shiny")
library("sortable")
library("ggplot2")
library("palmerpenguins")
library("dplyr")
library("tidyr")
penguins = drop_na(penguins)

ui = fluidPage(

  sortable_js("all_plots"),
  
  titlePanel("{sortable}"),
  
  fluidRow(
    column(
      width = 12,
      align = "center",
      checkboxGroupInput(
        "island",
        "Select Island",
        choices = unique(penguins$island),
        selected = unique(penguins$island),
        inline = TRUE
      )
    )
  ),
  
  tags$div(
    id = "all_plots",
    column(
      width = 6,
      wellPanel(
        plotOutput("scatter")
      )
    ),
    column(
      width = 6,
      wellPanel(
        plotOutput("bill_length")
      )
    ),
    column(
      width = 6,
      wellPanel(
        plotOutput("bill_depth")
      )
    ),
    column(
      width = 6,
      wellPanel(
        plotOutput("penguin_count")
      )
    )
  )
)

server = function(input, output, session) {
  
  penguins_subset = reactive({
    filter(penguins,
           island %in% input$island)
  })

  output$scatter = renderPlot({
    ggplot(penguins_subset(),
           aes(x = bill_length_mm,
               y = bill_depth_mm,
               colour = species)) +
      geom_point() +
      theme_minimal(base_size = 20)
  })

  output$bill_length = renderPlot({
    ggplot(penguins_subset(),
           aes(x = bill_length_mm,
               fill = species)) +
      geom_density(alpha = 0.5) +
      theme_minimal(base_size = 20)
    
  })

  output$bill_depth = renderPlot({
    ggplot(penguins_subset(),
           aes(x = bill_depth_mm,
               fill = species)) +
      geom_density(alpha = 0.5) +
      theme_minimal(base_size = 20)
  })
  
  output$penguin_count = renderPlot({
    ggplot(penguins_subset(),
           aes(x = species,
               fill = species)) +
      geom_bar() +
      theme_minimal(base_size = 20)
  })
}

shinyApp(ui, server)