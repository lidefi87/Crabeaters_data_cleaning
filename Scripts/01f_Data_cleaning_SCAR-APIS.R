###############################################################################
# Cleaning crabeater seal data obtained from SCAR APIS
# Author: Denisse Fierro Arcos
# Date: 2023-02-07
# 
# Crabeater seal data downloaded from SCAR APIS 1980-90

# Loading libraries -------------------------------------------------------
library(tidyverse)
library(CoordinateCleaner)

# Loading data downloaded from SCAR ---------------------------------------
scar_data <- read_delim("Data/SCAR_APIS_1980-90/occurrence.txt") %>% 
  #Remove empty columns
  janitor::remove_empty("cols") %>% 
  #Selecting only observations for crabeater seals
  filter(species == "Lobodon carcinophaga") %>% 
  #Removing observations for which there is no date
  drop_na(eventDate) %>% 
  #Dropping any records with reported geospatial issues
  filter(hasGeospatialIssues == F) %>% 
  #Removing any records with zeroes in individual count
  filter(individualCount != 0) %>% 
  #Removing any observations north of 45S as it is beyond the Southern Ocean boundaries
  filter(decimalLatitude <= -45) %>%
  #Removing known default values for coordinate uncertainty
  filter(!coordinateUncertaintyInMeters %in% c(301, 3036, 999, 9999)) %>% 
  #Removing observations with low coordinate precision. We chose to remove observations with precision over
  #10 km because this is the nominal horizontal resolution of our environmental data
  filter(coordinateUncertaintyInMeters <= 10000 | is.na(coordinateUncertaintyInMeters)) %>% 
  #Removing observations with no information in the "individual counts" column
  drop_na(individualCount) %>% 
  #Removing duplicate observations - based on lat/lon coordinates and date of observation
  distinct(eventDate, decimalLatitude, decimalLongitude, .keep_all = T)

#Second filter - Coordinate cleaner
scar_CC <- scar_data %>% 
  #Removing records with invalid coordinates and potential outliers
  clean_coordinates(lon = "decimalLongitude", lat = "decimalLatitude")
#Checking results
summary(scar_CC)
#No problematic data points detected

#Final check for coordinate issues
scar_CC <- scar_data %>% 
  #Checking potential issues with coordinate conversions and rounding
  cd_ddmm(lon = "decimalLongitude", lat = "decimalLatitude", ds = "datasetKey") %>% 
  #Removing duplicated records - based on coordinates and date of observation
  cc_dupl(lon = "decimalLongitude", lat = "decimalLatitude", additions = c("eventDate"))

#Saving clean dataset 
scar_CC %>% 
  write_csv("Cleaned_Data/SCAR-APIS_cleaned.csv")
