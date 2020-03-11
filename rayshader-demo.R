#### rayshader demo
# tutorial here: https://wcmbishop.github.io/rayshader-demo/

# dependencies (R): rayshader, leaflet, magick
# dependencies (outside R): XQuartz

#install.packages("rayshader")
#install.packages("leaflet")
library(rayshader)
library(leaflet)

# source extra functions from rayshader demo
if (!dir.exists("data")){ 
system("git clone https://github.com/wcmbishop/rayshader-demo.git") # clone repo
}
files.sources <- list.files("rayshader-demo/R/") # create list of files
sapply(paste0("rayshader-demo/R/", files.sources), source) # apply source to all files

# create directory structure
if (!dir.exists("data")){dir.create("data")} 
if (!dir.exists("images")){dir.create("images")}

# define bounding box with longitude/latitude coordinates
bbox <- list(
  p1 = list(long = -122.522, lat = 37.707),
  p2 = list(long = -122.354, lat = 37.84)
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

# restrict image to size of box
image_size <- define_image_size(bbox, major_dim = 600)

# download elevation data
elev_file <- file.path("data", "sf-elevation.tif")
get_usgs_elevation_data(bbox, size = image_size$size, file = elev_file, sr_bbox = 4326, sr_image = 4326)

# plotting the final map
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

# plot 2D
elev_matrix %>%
  sphere_shade(texture = "imhof4") %>%
  add_water(watermap, color = "imhof4") %>%
  add_shadow(raymat, max_darken = 0.5) %>%
  add_shadow(ambmat, max_darken = 0.5) %>%
  plot_map()

# fetch overlay image
overlay_file <- "images/sf-map.png"
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

# 3D map with overlay
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

# define label
label <- list(text = "Sutro Tower")
label$pos <- find_image_coordinates(
  long = -122.452131, lat = 37.756735, bbox = bbox,
  image_width = image_size$width, image_height = image_size$height)

# plot 3D (but only renders in 2D?)
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
render_label(elev_matrix, x = label$pos$x, y = label$pos$y, z = 500, zscale = zscale, text = label$text, textsize = 2, linewidth = 5)
#render_snapshot()

# montery water gif ====
elev_matrix <- montereybay
n_frames <- 180
zscale <- 50
# frame transition variables
waterdepthvalues <- min(elev_matrix)/2 - min(elev_matrix)/2 * cos(seq(0,2*pi,length.out = n_frames))
thetavalues <- -90 + 45 * cos(seq(0, 2*pi, length.out = n_frames))
# shadow layers
ambmat <- ambient_shade(elev_matrix, zscale = zscale)
raymat <- ray_shade(elev_matrix, zscale = zscale, lambert = TRUE)

# generate .png frame images
img_frames <- paste0("drain", seq_len(n_frames), ".png")
for (i in seq_len(n_frames)) {
  message(paste(" - image", i, "of", n_frames))
  elev_matrix %>%
    sphere_shade(texture = "imhof1") %>%
    add_shadow(ambmat, 0.5) %>%
    add_shadow(raymat, 0.5) %>%
    plot_3d(elev_matrix, solid = TRUE, shadow = TRUE, zscale = zscale, 
            water = TRUE, watercolor = "imhof3", wateralpha = 0.8, 
            waterlinecolor = "#ffffff", waterlinealpha = 0.5,
            waterdepth = waterdepthvalues[i]/zscale, 
            theta = thetavalues[i], phi = 45)
  render_snapshot(img_frames[i])
  rgl::clear3d()
}

# build gif
magick::image_write_gif(magick::image_read(img_frames), 
                        path = "montereybay.gif", 
                        delay = 6/n_frames)