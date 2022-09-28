library("shiny")
library("shinyglide")
library("ggplot2")
library("magrittr")


ui = fluidPage(
  h1("{shinyglide}"),
  div(
    id = "container",
    glide(
      custom_controls = glideControls(
        prevButton(class = "btn btn-warning"),
        nextButton(class = "btn btn-success")
      ),
      
      screen(
        h2(code("theme_classic()")),
        plotOutput("classic")
      ),
      
      screen(
        h2(code("theme_minimal()")),
        plotOutput("minimal")
      ),
      
      screen(
        h2(code("theme_void()")),
        plotOutput("void")
      )
    )
  )
)


server = function(input, output, session) {
  
  g = ggplot(mpg,
             aes(x = manufacturer, y = displ)) +
    geom_point() +
    coord_flip()
  
  output$classic = renderPlot({
    g +
      theme_classic(base_size = 20)
  })
  
  output$minimal = renderPlot({
    g +
      theme_minimal(base_size = 20)
  })
  
  output$void = renderPlot({
    g +
      theme_void(base_size = 20)
  })
}

shinyApp(ui, server)