*Add to CODE repo*

## Reproducing what we have done

All the data collection, manipulation and visualisation is reproducible. In the repo, there is a folder called *Reproducing*, in which each section below has its own folder. In each folder, data is given, along with the corresponding functions.

### Obtaining the data

A function to download all of the establishments in England can be found in the `data/` folder. The file is called *allEstablishmentsEnglandFunc.R* and the function is called `DownloadEstablishments()`. This function requires no input and the output is a data set with each row an establishment with 15 corresponding variables. The function takes about fifteen minutes to run on my laptop.

If you would just like the output, this can be found in the same folder - called *allEstablishmentsEngland.rds*. This data set was downloaded on 10 July 2021.

### Visualising the Data

Shapefiles for every postcode district in England can be found in the `data/` folder, called *spPoly.rds*. A function to combine these shapefiles with the establishment data can be found in the same folder in a file called *combiningEstPolyFunc.R*, the function is called `CombineSpatial()`. This function takes a data set of the establishments and the shapefile data as its inputs and outputs a SpatialPolygonsDataFrame which can then be plotted onto a map.

A function to obtain the choropleth map shown in the blog can be found in the same folder, the file is called *leafletMeanFHRFunc.R* and the function is called `LeafletMeanFHR()`. This function takes a `SpatialPolygonsDataFrame` as its only argument (the output of `CombineSpatial()` function will work perfectly) and outputs the Leaflet map as shown in the blog.

### Modelling

A data set containing every postcode in England with its corresponding deprivation data can be found in the `data/` folder - the data set is called *fullPostcodeDepData.rds*.

This data set can then be combined with the establishment data set with the following line:

  ```{r, eval = FALSE}
estDepMerged = merge(my_establishment_data, full_postcode_dep_data,
                     by.x = "postcode", by.y = "pcds")
```

which then produces the *estDepMerged* data set, used in all of the statistical modelling performed.




## Full model

So, to try and separate causation from correlation, we ultimately ended up with a model with the following covariates: deprivation data, the type of establishment, an indicator variable specifying whether or not the establishment was a chain, and the local authority of the establishment. 

```{r modellingextended, echo = FALSE, warning=FALSE, eval = FALSE, cache = TRUE}
chains = c("Gregg", "Domino", "Burger King", "Mcdonal", "KFC", "Pizza Hut", 
           "Subway", "Costa", "Toby Car", "Bella Ital", "PizzaE", "Nando", 
           "Harvester", "TGI F", "Papa J", "Asda", "Tesco", "Morrison", "Sainsbury")
regex = paste0("(?i)^(", paste(chains, collapse = "|"), ")")
estDepMerged$chain = stringr::str_detect(estDepMerged$name, regex)
#This takes a while to run, have saved to file
fullmodel <- MASS::polr(formula = as.factor(rating)~`Index of Multiple Deprivation (IMD) Score` + type + chain, 
                        data = estDepMerged)
#fullModel = readRDS(file = "data/fullModel.rds")
fullmodel_summary = summary(fullModel)
```
