library("httr")
library("jsonlite")
library("dplyr")

get_local_authority = function(id) {
  #Download by local authority
  path = "https://api.ratings.food.gov.uk/Establishments"
  request = httr::GET(url = path,
                      query = list(
                        localAuthorityId = id,
                        pageNumber = 1,
                        pageSize = 10000),
                      httr::add_headers("x-api-version" = "2"))

  # parse the response and convert to a data frame
  response = content(request, as = "text", encoding = "UTF-8") %>%
    jsonlite::fromJSON(flatten = TRUE) %>%
    purrr::pluck("establishments") %>%
    as_tibble()
  if (nrow(response) == 0) return(NULL)

  df = response %>%
    select(name = .data$BusinessName,
           type = .data$BusinessType,
           address1 = .data$AddressLine1,
           address2 = .data$AddressLine2,
           address3 = .data$AddressLine3,
           address4 = .data$AddressLine4,
           postcode = .data$PostCode,
           authorityNum = .data$LocalAuthorityCode,
           authorityName = .data$LocalAuthorityName,
           s_hygiene = .data$scores.Hygiene,
           s_structural = .data$scores.Structural,
           s_management = .data$scores.ConfidenceInManagement,
           long = .data$geocode.longitude,
           lat = .data$geocode.latitude,
           rating = .data$RatingValue) %>%
    tidyr::unite("address", .data$address1, .data$address2, .data$address3, .data$address4,
                 remove = TRUE, sep = ", ") %>%
    mutate(address = stringr::str_replace_all(.data$address, "NA,", ""),
           address = stringr::str_squish(.data$address),
           long = as.numeric(.data$long),
           lat = as.numeric(.data$lat))

  df
}

get_english_authorities = function() {
  #All_data now contains all establishments in the UK
  #Need to download the authority data to filter by only England
  path = "https://api.ratings.food.gov.uk/Authorities"
  request = httr::GET(url = path,
                      query = list(
                        localAuthorityId = 1,
                        pageNumber = 1,
                        pageSize = 10000),
                      httr::add_headers("x-api-version" = "2"))

  # # parse the response and convert to a data frame
  response = content(request, as = "text", encoding = "UTF-8") %>%
    jsonlite::fromJSON(flatten = TRUE) %>%
    purrr::pluck("authorities") %>%
    dplyr::as_tibble()

  authorities = dplyr::filter(response ,
                              !(.data$RegionName %in% c("Scotland", "Wales", "Northern Ireland")))
  return(authorities$Name)
}

download_establishments = function(ids = 1:500) {
  # Downloading all the establishments - across the UK
  All_data = purrr::map_dfr(ids, get_local_authority)

  auth_names = get_english_authorities()
  # We filter by establishments only in England
   #Also use regular expressions to extract postcodes
  establishments = All_data %>%
    dplyr::filter(.data$authorityName %in% auth_names)  %>%
    dplyr::mutate(postcodeArea = stringr::str_extract(.data$postcode, "[A-Z]+"),
                  postcodeDistrict = stringr::str_extract(.data$postcode, "\\w+"),
                  OverallRaw = .data$s_hygiene + .data$s_structural + .data$s_management)

  return(establishments)
}

establishments = download_establishments()
# saveRDS(establishments, file = "establishments.rds")
