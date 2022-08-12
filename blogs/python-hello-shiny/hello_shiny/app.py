from shiny import App, ui, render
import plotnine as gg
from plotnine.data import diamonds
import pandas as pd

# function that creates our UI based on the data
# we give it
def create_ui(data: pd.DataFrame):
  # calculate the set of unique choices that could be made
  choices = data['color'].unique()
  # create our ui object
  app_ui = ui.page_fluid(
    # row and column here are functions
    # to aid laying out our page in an organised fashion
    ui.row(
      ui.column(2, offset=1,*[
        # an input widget that allows us to select multiple values
        # from the set of choices
        ui.input_selectize(
          "select", "Color",
          choices=list(choices),
          multiple=True
        )]
      ),
      ui.column(1),
      ui.column(6,
        # an output container in which to render a plot
        ui.output_plot("out")
      )
    )
  )
  return app_ui

frontend = create_ui(diamonds)

# utility function to draw a scatter plot
def create_plot(data):
  plot = (
    gg.ggplot(data, gg.aes(x = 'carat', y='price', color='color')) + 
      gg.geom_point()
  )
  return plot.draw()

# wrapper function for the server, allows the data
# to be passed in
def create_server(data):
  def f(input, output, session):
  
    @output(id="out") # decorator to link this function to the "out" id in the UI
    @render.plot # a decorator to indicate we want the plot renderer
    def plot():
      color = list(input.select()) # access the input value bound to the id "select"
      sub = data[data['color'].isin(color)] # use it to create a subset
      plot = create_plot(sub) # create our plot
      return plot # and return it
  return f

server = create_server(diamonds)

app = App(frontend, server)