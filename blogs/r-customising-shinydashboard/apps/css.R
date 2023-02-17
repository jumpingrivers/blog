library("shiny")
library("shinydashboard")
library("dplyr")
library("ggplot2")
library("plotly")
library("knitr")
library("fresh")

my_theme = create_theme(
  adminlte_color(
    light_blue = "#4898a8"
  )
)


rent = readr::read_csv("rent_subset.csv",
                       show_col_types = FALSE,
                       progress = FALSE)
comma = scales::label_comma()

ui = dashboardPage(
  dashboardHeader(
    titleWidth = 300,
    title = "Bay Area Rent Prices"
  ),
  dashboardSidebar(
    width = 300,
    selectizeInput(
      "city",
      "City",
      choices = stringr::str_to_title(unique(rent$city)),
      selected = c("Half Moon Bay", "Mill Valley"),
      multiple = TRUE
    ),
    sliderInput(
      "beds",
      "Number of bedrooms",
      min = min(unique(rent$beds)),
      max = max(unique(rent$beds)),
      value = 1
    )
  ),
  dashboardBody(
    use_theme(my_theme),
    includeCSS("www/styles.css"),
    fluidRow(
      column(
        h2(textOutput("summary")),
        align = "center",
        width = 12
      )
    ),
    br(),
      valueBoxOutput("mean_price"),
      valueBoxOutput("max_price"),
      valueBoxOutput("min_price"),
      valueBoxOutput("mean_baths"),
      valueBoxOutput("mean_sqft"),
      valueBoxOutput("price_per_sqft"),
        box(
          title = "Average price comparison between cities",
          plotlyOutput("city_comparison"),
          width = 12
        )
  )
)

server = function(input, output, session) {


  filtered = reactive({
    rent %>%
      filter(
        city %in% tolower(input$city),
        beds == input$beds
      )
  })

  output$summary = renderText({
    paste0("Summary of ", input$beds, "-bedroom rental properties in ", knitr::combine_words(input$city))
  })

  output$mean_price = renderValueBox({
    valueBox(
      paste0("$", comma(round(mean(filtered()$price)))),
      "Mean rent price per month (in USD)",
      color = "light-blue"
    )
  })
  
  output$max_price = renderValueBox({
    valueBox(
      paste0("$", comma(round(max(filtered()$price)))),
      "Max. rent price per month (in USD)",
      color = "light-blue"
    )
  })
  
  output$min_price = renderValueBox({
    valueBox(
      paste0("$", comma(round(min(filtered()$price)))),
      "Min. rent price per month (in USD)",
      color = "light-blue"
    )
  })
  
  output$mean_baths = renderValueBox({
    valueBox(
      round(mean(filtered()$baths)),
      "Avg. number of bathrooms",
      color = "light-blue"
    )
  })
  
  output$mean_sqft = renderValueBox({
    valueBox(
      comma(round(mean(filtered()$sqft))),
      "Mean property size (in sq. ft.)",
      color = "light-blue"
    )
  })
  
  output$price_per_sqft = renderValueBox({
    valueBox(
      paste0("$", comma(round(mean(filtered()$price/filtered()$sqft)))),
      "Mean rent price (in USD) per sq. ft.",
      color = "light-blue"
    )
  })

  output$city_comparison = renderPlotly({
    g = rent %>%
      filter(beds == input$beds) %>%
      group_by(city) %>%
      summarise(mean_price = mean(price)) %>%
      mutate(city = stringr::str_to_title(city),
             city = reorder(city, mean_price),
             chosen_city = city %in% input$city,
             city_label = if_else(chosen_city, as.character(city), "")) %>%
      ggplot(aes(x = city, y = mean_price)) +
      geom_col(aes(fill = chosen_city)) +
      geom_text(aes(label = city_label), nudge_y = 150) +
      theme_minimal(base_size = 18) +
      theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(), legend.position = "none",
            plot.margin = margin(1,1,1,1, "cm")) +
      scale_fill_manual(values = c("#d6d6d6", "#4898a8")) +
      labs(x = "",
           y = "Mean price (in USD)
           \n") +
      scale_y_continuous(labels = scales::label_dollar())

    plotly::ggplotly(g, tooltip = "city")
  })
}

shinyApp(ui, server)
