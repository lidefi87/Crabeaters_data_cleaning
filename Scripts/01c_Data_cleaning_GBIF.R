###############################################################################
# Cleaning crabeater seal data obtained from GBIF using rgbif
# Author: Denisse Fierro Arcos
# Date: 2023-01-27
# 
# Crabeater seal data downloaded from GBIF using rgbif package.


# Loading libraries -------------------------------------------------------
library(rgbif)
library(tidyverse)
library(lubridate)
library(CoordinateCleaner)

# Searching data in GBIF --------------------------------------------------
#Accessing metadata for crabeater seals
crabeater <- name_backbone("Lobodon carcinophaga")

#Querying GBIF database
query <- occ_download(pred("taxonKey", crabeater$usageKey),+
                      #Keeping only records that are georeferenced
                      pred("hasCoordinate", TRUE))
#Starting download
occ_download_wait(query)

#Downloading all data to local disk - zip file is downloaded
crabeater_query <- occ_download_get(key = query, path = "Data/GBIF/rgbif_download/") %>% 
  occ_download_import(crabeaters_gbif, path = "Data/GBIF/rgbif_download/", na.strings = c("", NA))


# Cleaning data -----------------------------------------------------------
crabeater <- crabeater_query %>% 
  #Removing absent records
  filter(occurrenceStatus == "PRESENT") %>% 
  #Removing any observations north of 45S as it is beyond the Southern Ocean boundaries
  filter(decimalLatitude <= -45) %>% 
  #Removing any fossil or preserved specimen records
  filter(!basisOfRecord %in% c("PRESERVED_SPECIMEN", "FOSSIL_SPECIMEN")) %>% 
  #Removing any records with reported georeference issues 
  filter(hasGeospatialIssues == F) %>% 
  #Removing known default values for coordinate uncertainty
  filter(!coordinateUncertaintyInMeters %in% c(301, 3036, 999, 9999)) %>% 
  #Removing records from unknown sources
  drop_na(publisher) %>% 
  #Removing any records of dead or mummified animals
  filter(!str_detect(str_to_lower(occurrenceRemarks), "deceased|dead|died|mumm") | is.na(occurrenceRemarks)) %>% 
  #Removing any records identified as "approximate coordinates"
  filter(!str_detect(str_to_lower(occurrenceRemarks), 'coord.* approx') | is.na(occurrenceRemarks)) %>% 
  #Removing any records when latitude and longitude coordinates are exactly the same as this usually indicates
  #data entry errors
  filter(decimalLatitude != decimalLongitude) %>% 
  #Reclassifying bio-logging locations as 'MACHINE_OBSERVATIONS'
  mutate(basisOfRecord = case_when(str_detect(samplingProtocol, 'bio-log') & basisOfRecord != 'MACHINE_OBSERVATION' ~ 'MACHINE_OBSERVATION',
                                   T ~ basisOfRecord)) %>%
  #Changing observations with zeroes (0) in individual counts to 1. One record has life stage included and other records
  #belong to AAD ANARE database which only contains sightings and no absences (https://data.aad.gov.au/metadata/records/DB_Historic_WoV)
  mutate(individualCount = case_when(individualCount == 0 ~ 1, 
                                     T ~ individualCount)) %>% 
  #Removing observations from collection "ANTXXIII" because coordinates are all integers
  #The error associated to the reported location can be as large as 120 km
  filter(!str_detect(collectionCode, "ANTXXIII") | is.na(collectionCode)) %>% 
  #Removing observations with uncertainty about species - indicated by question mark
  filter(!str_detect(str_to_lower(occurrenceRemarks), 'seal.*\\?|crabeater.*\\?') | is.na(occurrenceRemarks)) %>% 
  #Removing observation with "PRESUMED_NEGATED_LATITUDE" as issue because it is too far inland
  filter(!str_detect(issue, "PRESUMED_NEGATED_LATITUDE") | is.na(issue)) %>% 
  #Adding year 2008 to Belgian expedition as that is the year the expedition took place
  mutate(eventDate = case_when(str_detect(collectionCode, "Belgian") ~ as_date(paste0("2008-", eventTime), format = "%Y-%d-%b"),
                               T ~ eventDate),
         #Ensuring year, month and date columns are filled in for all observations with an event date
         year = case_when(is.na(year) ~ year(eventDate), 
                          T ~ year),
         month = case_when(is.na(month) ~ month(eventDate), 
                           T ~ month),
         day = case_when(is.na(day) ~ day(eventDate), 
                T ~ day)) %>%
  #Removing any records with no date
  drop_na(eventDate) %>% 
  #Removing records prior to 1968 (beginning of modelled environmental data)
  filter(year >= 1968) %>% 
  #Removing duplicate observations - based on lat/lon coordinates and date of observation
  distinct(eventDate, decimalLatitude, decimalLongitude, .keep_all = T) %>% 
  #Removing observations with low coordinate precision. We chose to remove observations with precision over
  #10 km because this is the nominal horizontal resolution of our environmental data
  filter(coordinateUncertaintyInMeters <= 10000 | is.na(coordinateUncertaintyInMeters)) %>% 
  #Removing any empty columns
  janitor::remove_empty(which = "cols")

#Second filter - Coordinate cleaner
crabeater_CC <- crabeater %>% 
  #Removing records with invalid coordinates and potential outliers
  clean_coordinates(lon = "decimalLongitude", lat = "decimalLatitude") %>% 
  #Checking potential issues with coordinate conversions and rounding
  cd_ddmm(lon = "decimalLongitude", lat = "decimalLatitude", ds = "datasetKey") %>% 
  #Removing duplicated records - based on coordinates and date of observation
  cc_dupl(lon = "decimalLongitude", lat = "decimalLatitude", additions = c("year", "month", "day"))

#Saving clean dataset 
crabeater_CC %>% 
  write_csv("Cleaned_Data/GBIF_rgbif_cleaned.csv")

