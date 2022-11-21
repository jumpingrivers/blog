#' Server
#'
#' Core server function.
#'
#' @param input,output Input and output list objects
#' containing said registered inputs and outputs.
#' @param session Shiny session.
#'
#' @noRd
#' @keywords internal
server <- function(input, output, session){
  output$greeting <- renderText({
    req(input$greet)
    paste0("Hello ", isolate(input$name), "!")
  })

  output$spanish_greeting <- renderText({
    req(input$greet)
    paste0("Hola ", isolate(input$name), "!")
  })
}
