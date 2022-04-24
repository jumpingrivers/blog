library("dplyr")
library("leaflet")

fhr_leaflet_map = function(allPostcodesMerged) {
  #Mean food hygiene ratings
  bins = seq(3.5, 5, by = 0.25)
  pal_sb = leaflet::colorBin("RdYlGn", domain = allPostcodesMerged$mean, bins = bins)
  mytext = paste0(
    "Postcode district: ", allPostcodesMerged@data$name,"<br/>",
    "Count in district: ", allPostcodesMerged@data$count, "<br/>",
    "Mean hygiene rating: ", round(allPostcodesMerged@data$mean, 2)) %>%
    lapply(htmltools::HTML)

  leaflet() %>%
    leaflet::setView(lng = -0.75, lat = 53, zoom = 6) %>%
    leaflet::addTiles() %>%
    leaflet::addScaleBar() %>%
    leaflet::addPolygons(data = allPostcodesMerged,
                         fillColor = ~pal_sb(allPostcodesMerged$mean),
                         weight = 2,
                         opacity = 0.2,
                         label = mytext,
                         color = "white",
                         dashArray = "3",
                         fillOpacity = 0.5) %>%

    leaflet::addLegend(pal = pal_sb,
                       values = allPostcodesMerged$mean,
                       position = "bottomright",
                       title = "Mean Food Hygiene Rating")
}
