library("shiny")
library("shinycssloaders")
library("ggplot2")
library("dplyr")

ui = fluidPage(
  
  titlePanel("{shinycssloaders}"),
  
  withSpinner(
    plotOutput("scatter_plot")
  ),
  
  actionButton(
    "generate",
    "Re-generate!"
  )
)

server = function(input, output, session) {
  
  scatter_data = reactive({
    x = rnorm(100000)
    y = rnorm(100000)
    tibble(
      x = x,
      y = y
    )
  }) %>% 
    bindEvent(input$generate,
              ignoreNULL = FALSE)
  
  output$scatter_plot = renderPlot({
    scatter_data() %>%
      ggplot(aes(x = x, y = y)) +
      geom_point()
  })
}

shinyApp(ui, server)
