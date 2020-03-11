#### Feb 2020 San Francisco trees ####

library(tidyverse)
library(tidytuesdayR)

# download San Francisco trees data
tt_data<-tt_load("2020-01-28")
print(tt_data)

# extract data of interest
Street_Tree_Map <- tt_data$Street_Tree_Map
sf_trees <- tt_data$sf_trees

#### Notes about data ####

# Street_Tree_Map is raw data

sf_trees %>%
  group_by(species) %>%
  tally() %>%
  arrange(n) %>%
  tail()

sf_trees %>%
  group_by(caretaker) %>%
  tally() %>%
  arrange(n)
# species column includes latin and common name, separated by two colons, also lots of missing data included as Tree(s):: and some with ::


sf_trees %>%
  group_by(legal_status) %>%
  tally() %>%
  arrange(n)

sf_trees %>%
  group_by(site_info) %>%
  tally() %>%
  arrange(n) %>%
  tail()
# not super useful, categories are unclear


# issues with address column as well: some say stairwell
# lots of missing data for dbh and plot size

#### Recommendations ####

# replace all Trees(s):: and :: in species column with NA
# find some geospatial mapping data/packages: demo here https://wcmbishop.github.io/rayshader-demo/

#### Ideas for visualizations ####

# punny plots with tree heights
# dbh: 
#   are there bigger trees in different parts of the city?
#   rayshader plot: dhb plotted as height above topographical map of san francisco
# distribution of undocumented trees
# time and tree size
# impute some of the data


