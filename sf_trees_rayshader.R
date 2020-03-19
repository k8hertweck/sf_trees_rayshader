#### San Francisco trees dataset visualized with rayshader ####

# dependencies (outside R): XQuartz

library(tidyverse)
library(tidytuesdayR)
library(leaflet)
library(rayshader)
#library(simputation)

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
if (file.exists("data/sf_trees_filtered.csv")){
  sf_trees <- read_csv("data/sf_trees_filtered.csv")
} else {
  tt_data<-tt_load("2020-01-28")
  sf_trees_raw <- tt_data$sf_trees
  
  # identify extent of tree data in lat/lon
  summary(sf_trees_raw[c("latitude","longitude")])
  hist(sf_trees_raw$latitude)
  hist(sf_trees_raw$longitude)
  
  # data filtering and cleaning (with help from Shashi!)
  sf_trees <- sf_trees_raw %>% 
    # remove trees missing data for species
    filter(species != "::" & species != "Tree(s) ::" ) %>% 
    # remove trees with no geospatial data
    filter(!is.na(latitude)) %>% 
    filter(!is.na(longitude)) %>% 
    # narrow scope of map
    filter(latitude > 37.71, latitude < 37.81) %>% # narrow the map
    filter(longitude < -122.36, longitude > -122.54) %>% 
    # remove trees with missing dbh
    filter(!is.na(dbh)) %>%
    filter(dbh < 9999) %>% # errant monster 
    # add placeholder date for old trees, split latin and common names
    mutate(date = replace_na(date, as.Date("1954-01-01")), 
           species_latin = str_extract(species, "^[\\w\\'\\s]+"), 
           species_common = str_extract(species, "[\\w\\'\\s]+$")) 
  write_csv(sf_trees, "data/sf_trees_filtered.csv")
}

# impute missing data for dbh 
#sf_trees <- impute_median(sf_trees, dbh ~ species_common)
# imputation isn't included in this analysis because there were too many trees to plot to begin with!

# subset trees
old_trees <- sf_trees %>%
  filter(date <= as.Date("1954-01-01"))
  
young_trees <- sf_trees %>%
  filter(date > as.Date("1954-01-01"))

big_trees <- sf_trees %>%
  filter(dbh > 100)

#### Plotting with leaflet and widgets ####

# define bounding box from coordinates
bbox <- list(
  p1 = list(long = -122.35, lat = 37.7),
  p2 = list(long = -122.55, lat = 37.82)
)

# show map with big trees, markers have dbh in mouseover and species with click
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
  ) %>%
  addMarkers(lng = big_trees$longitude, lat = big_trees$latitude, 
             popup = as.character(big_trees$species_common), 
             label = as.character(paste(big_trees$dbh, "cm")))

#### Plotting with rayshader

# restrict image to size of box
image_size <- define_image_size(bbox, major_dim = 600)

# download elevation data
if (file.exists("data/tree-elevation.tif")){
} else {
  elev_file <- file.path("data", "tree-elevation.tif")
  get_usgs_elevation_data(bbox, size = image_size$size, file = elev_file, sr_bbox = 4326, sr_image = 4326)
}

# load elevation data
elev_img <- raster::raster(elev_file)
elev_matrix <- matrix(
  raster::extract(elev_img, raster::extent(elev_img), buffer = 1000), 
  nrow = ncol(elev_img), ncol = nrow(elev_img)
)

# calculate rayshader layers
ambmat <- ambient_shade(elev_matrix, zscale = 30)
raymat <- ray_shade(elev_matrix, zscale = 30, lambert = TRUE)
watermap <- detect_water(elev_matrix)

# 2D plot
elev_matrix %>%
  sphere_shade(texture = "imhof4") %>%
  add_water(watermap, color = "imhof4") %>%
  add_shadow(raymat, max_darken = 0.5) %>%
  add_shadow(ambmat, max_darken = 0.5) %>%
  plot_map()

# fetch overlay image
overlay_file <- "images/tree-map.png"
get_arcgis_map_image(bbox, map_type = "World_Topo_Map", file = overlay_file, width = image_size$width, height = image_size$height, sr_bbox = 4326)
overlay_img <- png::readPNG(overlay_file)

# 2D plot with map overlay
elev_matrix %>%
  sphere_shade(texture = "imhof4") %>%
  add_water(watermap, color = "imhof4") %>%
  add_shadow(raymat, max_darken = 0.5) %>%
  add_shadow(ambmat, max_darken = 0.5) %>%
  add_overlay(overlay_img, alphalayer = 0.5) %>%
  plot_map()

# prep label for monster tree
biggest_tree <- big_trees %>%
  filter(dbh > 3000)
label <- list(text = "biggest tree")
label$pos <- find_image_coordinates(
  long = biggest_tree$longitude, lat = biggest_tree$latitude, bbox = bbox,
  image_width = image_size$width, image_height = image_size$height)

# plot 3D
zscale <- 10
rgl::clear3d()
elev_matrix %>% 
  sphere_shade(texture = "imhof4") %>% 
  add_water(watermap, color = "imhof4") %>%
  add_overlay(overlay_img, alphalayer = 0.5) %>%
  add_shadow(raymat, max_darken = 0.5) %>%
  add_shadow(ambmat, max_darken = 0.5) %>%
  plot_3d(elev_matrix, zscale = zscale, windowsize = c(1200, 1000),
          water = TRUE, soliddepth = -max(elev_matrix)/zscale, wateralpha = 0,
          theta = 25, phi = 30, zoom = 0.65, fov = 60)
# add label
render_label(elev_matrix, x = label$pos$x, y = label$pos$y, z = 200, zscale = zscale, text = label$text, textsize = 2, linewidth = 5)
render_snapshot()
