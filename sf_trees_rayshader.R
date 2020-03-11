#### San Francisco trees dataset visualized with rayshader ####

library(tidyverse)
library(tidytuesdayR)
library(leaflet)
library(rayshader)

# source extra functions from rayshader demo
if (!dir.exists("data")){ 
  system("git clone https://github.com/wcmbishop/rayshader-demo.git") # clone repo
}
files.sources <- list.files("rayshader-demo/R/") # create list of files
sapply(paste0("rayshader-demo/R/", files.sources), source) # apply source to all files

# create directory structure
if (!dir.exists("data")){dir.create("data")} 
if (!dir.exists("images")){dir.create("images")}

#### Download and extract tree data ####

# download data
tt_data<-tt_load("2020-01-28")
sf_trees <- tt_data$sf_trees

# identify extent of tree data in lat/lon
summary(sf_trees[c("latitude","longitude")])

#### Create basis for map

# define bounding box from coordinates
bbox <- list(
  p1 = list(long = -122, lat = 37),
  p2 = list(long = -139, lat = 48)
)

# show map
leaflet() %>%
  addTiles() %>% 
  addRectangles(
    lng1 = bbox$p1$long, lat1 = bbox$p1$lat,
    lng2 = bbox$p2$long, lat2 = bbox$p2$lat,
    fillColor = "transparent"
  ) %>%
  fitBounds(
    lng1 = bbox$p1$long, lat1 = bbox$p1$lat,
    lng2 = bbox$p2$long, lat2 = bbox$p2$lat,
  )
