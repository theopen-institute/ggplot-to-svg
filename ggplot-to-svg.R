# This script uses dplyr version 0.6.0, which at time of writing has not yet been released.
# It should be out imminently, but in the meantime we need to use the github version
library(devtools)
# Uncomment the line below to install development version of dplyr from github
#devtools::install_github("tidyverse/dplyr")

# Required libraries
library(foreign)   # to import the NLSS files from Stata format
library(dplyr)     # to manipulate our data into a aggregated format
library(tidyr)     # to mark missing district data explicitly as missing 
library(binom)     # to calculate confidence intervals
library(sp)        # to import our map geospatial data
library(broom)     # to convert our map data to a format ggplot can read
library(ggplot2)   # to build our choropleth visual object
library(gridSVG)   # to convert our ggplot grid to SVG
library(XML)       # to convert gridSVG XML representation to text
library(xml2)      # to manipulate our SVG object
library(rjson)     # to encode our data in order to embedd it in the SVG graphic file


###########################################################################################
##  Section 1: building our data                                                         ##
###########################################################################################
#
# In this section, we'll build our data object.
# Subsequent sections expect a data frame named "dist.table" with the following properties:
#   - Exactly 1 column named "district" which specifies the region name from our map data
#   - Between 1 and 10 columns named "*.prop", where "*" represents the name of our measurement
#   - Optionally, a *.conf_lower and *.conf_upper representing confidence bounds for each measurement
#
# If you do not have access to the NLSS 2011 microdata, you may use a prebuilt table included here.
# Run the following command and skip to Section 2:
#    dist.table <- readRDS("mapdata.rds")

# these commands import the relevant sections from the NLSS 2011 survey
s00 <- read.dta("xh00_s00.dta")
s02 <- read.dta("xh02_s02.dta")
s06c <- read.dta("xh08_s06c.dta")
durable.goods <- left_join(s06c, s00)
households <- left_join(s02, s00)

# these three functions transform our household-level microdata into district-wise aggregates
item_analyze <- function(df) {
  df %>%
    complete(district) %>%
    mutate(prop = own/n) %>%
    rowwise %>%
    mutate(conf_lower = if (is.na(own) | is.na(n)) { NA } else { binom.exact(own,n)$lower }) %>%
    mutate(conf_upper = if (is.na(own) | is.na(n)) { NA } else { binom.exact(own,n)$upper })
}

# pre-cursor function with specific instructions for s06a-style variables
item_s06a <- function(base, id) {
  base %>%
    filter(v06c_idc == id) %>%
    group_by(district = v00_dist) %>%
    summarize(n = n(),
              own = sum(v06_05=="yes")) %>%
    item_analyze()
}

# pre-cursor function with specific instructions for s02-style variables
item_s02 <- function(base, var) {
  var <- enquo(var)
  base %>%
    group_by(district = v00_dist) %>%
    summarize(n = n(),
              own = sum(UQ(var) == "yes")) %>%
    item_analyze()
}

# utility function to add key-name prefixes to the output of item_analyze()
prefix_vars <- function(df, key) {
  p1 <- paste0(key,".prop")
  p2 <- paste0(key,".conf_lower")
  p3 <- paste0(key,".conf_upper")
  df %>%
    select(district,n, !!p1 := prop, !!p2 := conf_lower, !!p3 := conf_upper)
}

# using our aggregation functions above, assemble ownership rates per district for our ten items
bicycle.ownership      <- item_s06a(durable.goods, 503) %>% prefix_vars("bicycle")
motorcycle.ownership   <- item_s06a(durable.goods, 504) %>% prefix_vars("motorcycle")
car.ownership          <- item_s06a(durable.goods, 505) %>% prefix_vars("car")
refrigerator.ownership <- item_s06a(durable.goods, 506) %>% prefix_vars("refrigerator")
television.ownership   <- item_s06a(durable.goods, 510) %>% prefix_vars("television")
computer.ownership     <- item_s06a(durable.goods, 517) %>% prefix_vars("computer")
telephone.ownership    <- item_s02(households, v02_31a) %>% prefix_vars("telephone")
mobile.ownership       <- item_s02(households, v02_31b) %>% prefix_vars("mobile")
cable.ownership        <- item_s02(households, v02_31c) %>% prefix_vars("cable")
internet.ownership     <- item_s02(households, v02_31d) %>% prefix_vars("internet")

# combine these tables together into our final, output-bound object
dist.table <- bicycle.ownership %>%
  left_join(motorcycle.ownership) %>%
  left_join(car.ownership) %>%
  left_join(refrigerator.ownership) %>%
  left_join(television.ownership) %>%
  left_join(computer.ownership) %>%
  left_join(telephone.ownership) %>%
  left_join(mobile.ownership) %>%
  left_join(cable.ownership) %>%
  left_join(internet.ownership) %>%
  arrange(tolower(district))

# fix mislabeled name of district #24 (previously just "kavre")
levels(dist.table$district)[24] <- "kavrepalanchok"


###########################################################################################
##  Section 2: building our map                                                          ##
###########################################################################################
#
# To build our map, we'll use data about Nepal's borders from GADM.org.
# GADM offers data in several different formats and at several levels of detail
# but the map we want is in the format "R SpatialPolygonsDataFrame" (.rds), and we'll
# use Level 3 (districts). We'll use the tidy package to convert that file over to something
# that ggplot can use

# set up our map, convert district names to lowercase, and convert to a ggplot compatible format
np.dists <- readRDS("NPL_adm3.rds")
np.dists$NAME_3 <- tolower(np.dists$NAME_3)
map.polygons <- tidy(np.dists, region = "NAME_3")

# If we want to manually specify our image dimensions, we can create a new output device
#quartz(width=16, height=7.5, antialias=TRUE)

## draw our map
map <- ggplot(data=dist.table, mapping=aes(map_id = district, fill = bicycle.prop)) + 
  geom_map(map = map.polygons) + 
  expand_limits(x = map.polygons$long, y = map.polygons$lat) +
  scale_fill_gradient2(low = "#132B43", mid="#56B1F7", high = "#FFFFFF", midpoint=.8, limits=c(0,1),
                       breaks = c(0, .25, .5, .75, 1), labels=c("0%","25%","50%","75%","100%"),
                       guide=guide_colorbar(title="Households", barwidth=1.5, barheight=10, raster=FALSE)) +
  labs(x=NULL, y=NULL,caption="Data assembled from the Nepal Living Standard Survey, 2011")


###########################################################################################
##  Section 3: converting our ggplot map into the SVG format                             ##
###########################################################################################
# Turn our ggplot map into an svg object
# We'll use a png output device to manually control width and height parameters
png(filename="temp.png", width=1024, height=480, unit="px")
map
map.svg <- grid.export("temp.svg",addClasses=TRUE, strict=TRUE, progress=TRUE,
                       exportMappings="inline", exportCoords="inline", res=72)
dev.off()

###########################################################################################
##  Section 4: prepping auxiliary data to go along with the SVG image                    ##
###########################################################################################
# extract our district data from the ggplot object and convert it into a list format
map_data <- map$data %>% 
  apply(MARGIN=1,FUN=function(x)return(list(x)))

# extract our map's color scale information
n <- map$scales$get_scales("fill")
colors <- seq(0,1,.001) %>% data.frame(fill=., row.names=NULL) %>% n$map_df()
NA_color <- rgb(col2rgb(n$na.value)[1,], col2rgb(n$na.value)[2,], col2rgb(n$na.value)[3,], maxColorValue=255)


###########################################################################################
##  Section 5: assemble our XML document                                                 ##
###########################################################################################
# 
# Note: Sections 1-4 are purely functional, but this section

# manually adjust a few of the SVG structure's details
svg.text <- read_xml(saveXML(map.svg$svg))
xml_set_attr(svg.text, "height", NULL)
xml_set_attr(svg.text, "width", NULL)
xml_set_attr(svg.text, "viewBox", paste("0 0", map.svg$coords$ROOT$width, map.svg$coords$ROOT$height))
svg.text.g <- xml_child(svg.text, search="d1:g")
xml_set_attr(svg.text.g, "transform", paste0("translate(0, ", map.svg$coords$ROOT$height, ") scale(1, -1)"))

## add our dataset, color key, d3 reference, and script reference
output_data <- read_xml(paste("<script>dataset=",rjson::toJSON(map_data),"</script>"))
color_key <- read_xml(paste("<script>na_color=",rjson::toJSON(NA_color),"; colorkey=", rjson::toJSON(colors$fill), "</script>"))
d3 <- read_xml('<script xlink:href="https://cdnjs.cloudflare.com/ajax/libs/d3/4.9.1/d3.min.js"></script>')
script <- read_xml("<script xlink:href='./map-svg.js'></script>")
xml_add_child(svg.text,output_data)
xml_add_child(svg.text,color_key)
xml_add_child(svg.text,d3)
xml_add_child(svg.text,script)


## prep our final output
output <- xml_new_root(
  xml_dtd("svg", "-//W3C//DTD SVG 1.1//EN", "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd")
)
xml_add_child(output,svg.text)
write_xml(output, "map.svg")
