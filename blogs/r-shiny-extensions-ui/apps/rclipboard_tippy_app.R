library("shiny")
library("tippy")
library("rclipboard")
library("dplyr")

ui = fluidPage(
  
  tags$head(
    tags$style(HTML(".tippy-tooltip {
                      font-size: 15px;
                    }
                    
                    #string_text {
                      text-align: center;
                      margin-top: 50px;
                      font-size: 20px;
                      font-weight: bold;
                      margin-bottom: 10px;
                    }
                    
                    div[role='main'] {
                      display: grid;
                      place-items: center;
                    }
                    "))
  ),
  
  
  rclipboardSetup(),
  
  titlePanel("{tippy} and {rclipboard}"),
  
  sidebarLayout(
    sidebarPanel(
      sliderInput(
        "n_characters",
        "Number of characters:",
        min = 1,
        max = 20,
        value = 12
      ),
      actionButton("generate",
                   "Generate random string!"),
      hr(),
      uiOutput("enter_string")
    ),
    
    mainPanel(
      textOutput("string_text"),
      
      uiOutput("clip"),
      
      tippy_this(
        "clip",
        tooltip = "String copied!",
        trigger = "click",
        placement = "right",
        arrow = "true"
      )
    )
  )
)

server = function(input, output, session) {
  
  random_string = reactive({
    alphanumeric = c(LETTERS, letters, 0:9)
    paste0(
      sample(alphanumeric, input$n_characters, replace = TRUE), 
      collapse = ""
    )
  }) %>% 
    bindEvent(input$generate)
  
  output$string_text = renderText({
    random_string()
  })
  
  output$clip = renderUI({
    rclipButton(
      "clipbtn",
      "Copy to clipboard",
      random_string(),
      icon = icon("clipboard"))
  })
  
  output$enter_string = renderUI({
    textInput("enter_string",
              "Paste string here:")
  }) %>%
    bindEvent(input$generate)
}

shinyApp(ui, server)