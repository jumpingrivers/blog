# Scores on the Doors

See the [blog post](https://jumpingrivers.com/blog/food-hygiene-ratings-uk-deprivation/)
for details. The structure of this repo is relatively simple.

 * `R/` contains all R code used in the blog posts
 * `data/` contains both data files, such as postcodes, and also intermediate cached files.

### Obtaining

The scores on the doors data set is obtained using the `download_establishments()` found in `R/download_establishments.R`. The data file, `establishments.rds` contains the 
data from on 10 July, 2021.

### Visualisation

Shapefiles for every postcode district in England can be found in the `data/spPoly.rds`. 
This dataset is then merged with the establishments (`R/create_merged_postcodes.R`).
The data is plotted using `R/fhr_leaflet_map.R`.

### Modelling

A data set containing every postcode in England with its corresponding deprivation data can be found in the `data/` folder - the data set is called `data/fullPostcodeDepData.rds.
This data set can then be combined with the establishment data set with the following line:

```
estDepMerged = merge(my_establishment_data, full_postcode_dep_data,
                     by.x = "postcode", by.y = "pcds")
```

The basic model can be fitted using

```
MASS::polr(formula = factor(rating) ~ `Index of Multiple Deprivation (IMD) Score`,
                   data = estDepMerged)
```        

Alternatively, a move complex model using deprivation data, the type of establishment, an indicator variable specifying whether or not the establishment was a chain, and the local authority of the establishment. 

```
chains = c("Gregg", "Domino", "Burger King", "Mcdonal", "KFC", "Pizza Hut", 
           "Subway", "Costa", "Toby Car", "Bella Ital", "PizzaE", "Nando", 
           "Harvester", "TGI F", "Papa J", "Asda", "Tesco", "Morrison", "Sainsbury")
regex = paste0("(?i)^(", paste(chains, collapse = "|"), ")")
estDepMerged$chain = stringr::str_detect(estDepMerged$name, regex)
# This takes a while to run
fullmodel = MASS::polr(formula = as.factor(rating) ~ 
  `Index of Multiple Deprivation (IMD) Score` + 
  type + 
  chain, data = estDepMerged)
summary(fullModel)
```

## About

This work was initially carried out by [James Salsbury](http://maths.dept.shef.ac.uk/maths/staff_info_987.html) as part of his MMathStat project at Newcastle University. James is now a PhD student at the University of Sheffield looking at Bayesian experimental design for adaptive clinical trials.
