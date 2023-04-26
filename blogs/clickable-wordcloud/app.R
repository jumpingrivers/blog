library("shiny")
library("dplyr")
library("stringr")
library("tidytext")
library("wordcloud2")
library("DT")

my_palette = c("#355070",
               "#6d597a",
               "#b56576",
               "#e56b6f",
               "#eaac8b")

tuesdata = tidytuesdayR::tt_load("2021-04-20")
netflix_titles = tuesdata$netflix_titles

word_counts = netflix_titles %>%
  unnest_tokens("word", title) %>%
  anti_join(stop_words, by = "word") %>%
  count(word) %>%
  filter(n > 10)

my_wordcloud = wordcloud2(
  word_counts,
  color = rep_len(my_palette,
                  nrow(word_counts)))

ui = fluidPage(
  wordcloud2Output("wordcloud"),
  tags$script(HTML(
    "$(document).on('click', '#canvas', function() {
      word = document.getElementById('wcLabel').textContent;
      Shiny.onInputChange('clicked_word', word);
    });")),
  DT::DTOutput("filtered_tbl")
)

server = function(input, output) {
  output$wordcloud = renderWordcloud2(my_wordcloud)
  
  filtered_netflix = reactive({
    clicked_word = str_remove(input$clicked_word, ":[0-9]+$")
    
    netflix_titles %>%
      filter(str_detect(tolower(title), clicked_word)) %>%
      select(title, everything(), -show_id)
  })
  
  output$filtered_tbl = DT::renderDT(filtered_netflix())
}

shinyApp(ui, server)