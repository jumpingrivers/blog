library("dplyr")
library("sp")

get_post_code_areas = function() {
  c("AL" ,"B", "BA" ,"BB" ,"BD" ,"BH" ,"BL" ,"BN" ,"BR" ,"BS", "CA", "CB",
    "CH", "CM" ,"CO" ,"CR" ,"CT" ,"CV", "CW", "DA" ,"DE", "DG","DH",
    "DL", "DN", "DT", "DY", "E" ,"EC", "EN" ,"EX", "FY","GL" ,
    "GU", "HA", "HD" ,"HG", "HP", "HR","HU", "HX", "IG", "IP",
    "KT", "L", "LA", "LD", "LE", "LL","LN", "LS", "LU" ,"M", "ME", "MK",
    "N", "NE" ,"NG" ,"NN","NP", "NR", "NW", "OL", "OX", "PE",
    "PL", "PO", "PR", "RG", "RH", "RM", "S","SE", "SG", "SK", "SL", "SM",
    "SN", "SO", "SP", "SR", "SS", "ST", "SW","SY", "TA", "TD", "TF", "TN", "TQ",
    "TR", "TS", "TW", "UB", "W", "WA", "WC", "WD", "WF", "WN", "WR", "WS", "WV",
    "YO")
}

summarise_post_code = function(allEstablishmentsEngland, post_code) {
  allEstablishmentsEngland %>%
    dplyr::filter(.data$postcodeArea == post_code) %>%
    dplyr::mutate(rating = as.numeric(.data$rating)) %>%
    dplyr::group_by(.data$postcodeDistrict) %>%
    dplyr::summarise(mean = mean(.data$rating), sd = sd(.data$rating),
                     count = n(), rawmean = mean(.data$OverallRaw))
}

fix_bad_postcode = function(post_code,
                            merged_summary, postcode_summary) {
  postcodeAreas = get_post_code_areas()
  badPostcodeAreas = postcodeAreas[c(10, 18, 31)]
  bad_post_code = which(post_code == badPostcodeAreas)
  if (!any(bad_post_code)) return(merged_summary)
  bad_district = c(9, 28, 27)[bad_post_code]
  bad_name = c(2, 7, 33)[bad_post_code]

  merged_summary@data[bad_name,]$mean = postcode_summary[[bad_district, 2]]
  merged_summary@data[bad_name + 1,]$mean = postcode_summary[[bad_district, 2]]
  merged_summary@data[bad_name,]$sd = postcode_summary[[bad_district, 3]]
  merged_summary@data[bad_name + 1,]$sd = postcode_summary[[bad_district, 3]]
  merged_summary@data[bad_name,]$count = postcode_summary[[bad_district, 4]]
  merged_summary@data[bad_name + 1,]$count = postcode_summary[[bad_district, 4]]
  merged_summary@data[bad_name,]$rawmean = postcode_summary[[bad_district, 5]]
  merged_summary@data[bad_name + 1,]$rawmean = postcode_summary[[bad_district, 5]]

  merged_summary
}

CombineSpatial = function(allEstablishmentsEngland, spPoly) {

  allEstablishmentsEngland = allEstablishmentsEngland %>%
    dplyr::filter(.data$rating %in% 0:5) %>%
    dplyr::filter(.data$OverallRaw %in% 0:80)
  postcodeAreas = get_post_code_areas()

  merged_sp_summary = list()
  for (i in seq_along(postcodeAreas)) {
    #Get the postcode data, only numeric values
    post_code = postcodeAreas[i]

    #Get a summary of the postcode data
    postcode_summary = summarise_post_code(allEstablishmentsEngland, post_code)

    #Merge the spatial and postcode summary data
    merged_summary = sp::merge(spPoly[[post_code]], postcode_summary,
                               by.x = "name", by.y = "postcodeDistrict")
    merged_summary@data[is.na(merged_summary@data)] = 0
    merged_summary = fix_bad_postcode(post_code, merged_summary, postcode_summary)
    merged_sp_summary[[post_code]] = merged_summary
  }

  purrr::reduce(merged_sp_summary, rbind)
}
allEstablishmentsEngland = readRDS("data/obtain/allEstablishmentsEngland.rds")
spPoly = readRDS("data/visualise/spPoly.rds")
merged_postcodes = CombineSpatial(allEstablishmentsEngland, spPoly)

#identical(merged_postcodes, readRDS("Reproducing/visualisingData/merged_postcodes.rds"))
#saveRDS(merged_postcodes, file="Reproducing/visualisingData/merged_postcodes.rds")








