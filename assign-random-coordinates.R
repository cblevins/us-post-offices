### This program takes post offices from the Richard Helbock dataset that I was unable to geolocate using GNIS Features. It then assigns them a set of coordinates that were randomly generated within their county's boundaries in the year 2000. 
### The randomly generated points were created using QGIS's Random Points Inside Polygon tool in May 2020 on county boundaries from the year 2000 using the boundary shapefiles from the Newberry Library's Atlas of Historical County Boundaries.
### Note: The resulting dataset should only be used for illustrative, rather than analytic, purposes. Especially in counties or states with a low "match" rate in terms of the total number of post offices that were successfully geolocated, including their remaining post offices with randomly distributed coordinates can create a more accurate impression of the rough density in that county/state.

library(tidyverse)
library(data.table)

# Load in Helbock's Post Offices that have been geolocated
postoffices_original<-read.csv("output/us-post-offices.csv", stringsAsFactors = FALSE)
postoffices<-postoffices_original
postoffices$Established<-as.integer(as.character(postoffices$Established)) #convert years to integers
postoffices$Discontinued<-as.integer(as.character(postoffices$Discontinued)) #convert years to integers
postoffices<-postoffices[order(postoffices$Established) ,] #order ascending based on established date
postoffices[,1:5]<-lapply(postoffices[,1:5], function(x) str_conv(x, "utf-8")) #convert to UTF
postoffices[,1:5]<-lapply(postoffices[,1:5], function(x) str_trim(x)) #clean up white spaces

#Load in a file containing 150 randomly generated coordinates for each county in the US in year 2000
random_coords<-read.csv("data/random-coordinates-150-per-county.csv", stringsAsFactors = FALSE, header = T)
random_coords<- random_coords %>% rename("Longitude" = "X", "Latitude"="Y", "key"="KEY_UPPER")

#getting a list of unique state + county combinations from Helbock dataset and the number of post offices with missing coordinates
postoffices<-postoffices %>% mutate(RandomCoordsFlag=FALSE)
postoffices_backup<-postoffices
postoffices_unmatched <- postoffices %>% 
  filter(Coordinates==FALSE) %>%
  select(ID, County1, State, Latitude, Longitude, RandomCoordsFlag) %>%
  unite("key", State, County1, sep="_", remove=FALSE)
counties_unmatched <- postoffices_unmatched %>%
  group_by(key) %>%
  summarise(missing=n()) %>%
  arrange((key))

#go through each unique state + county for which you have missing coordinates, look up in the table of randomly distributed points, and create a running dataframe of post offices that you are adding coordiantes to
postoffices_unmatched_running<-postoffices_unmatched[0,] #empty dataframe
#counties_unmatched<-counties_unmatched %>% sample_n(20)

for (i in 1:nrow(counties_unmatched)) {
  countykey<-counties_unmatched$key[i]
  nummissingcoords<-counties_unmatched$missing[i]
  postoffices_unmatched_subset<- postoffices_unmatched %>% filter(key==countykey)
  random_coords_subset<-random_coords %>% filter(key==countykey) %>% sample_n(nummissingcoords)
  if(nrow(random_coords_subset)==0) {
    postoffices_unmatched_running<-postoffices_unmatched_running %>% bind_rows(postoffices_unmatched_subset)
    next
  } else {
    postoffices_unmatched_subset$Longitude <- random_coords_subset$Longitude
    postoffices_unmatched_subset$Latitude <- random_coords_subset$Latitude
    postoffices_unmatched_subset$RandomCoordsFlag <- TRUE
    postoffices_unmatched_running<-postoffices_unmatched_running %>% bind_rows(postoffices_unmatched_subset)
  }
}

#merge into the main dataframe of all post offices
postoffices<-postoffices_backup
postoffices_randomcoords<-postoffices %>% 
  left_join(postoffices_unmatched_running %>% select(ID, Longitude, Latitude, RandomCoordsFlag), by="ID") %>%
  mutate(Longitude=ifelse(!is.na(Longitude.y), yes=Longitude.y, no=Longitude.x)) %>%
  mutate(Latitude=ifelse(!is.na(Latitude.y), yes=Latitude.y, no=Latitude.x)) %>%
  mutate(RandomCoordsFlag=ifelse(!is.na(RandomCoordsFlag.y), yes=RandomCoordsFlag.y, no=RandomCoordsFlag.x)) %>%
  mutate(Coordinates=ifelse(!is.na(Longitude), yes=TRUE, no=FALSE)) %>%
  #select(Post.Office:GNIS.Dist, Latitude, Longitude, RandomCoordsFlag, -(Latitude.x:RandomCoordsFlag.y))
  select(Name:GNIS.MatchScore, Latitude, Longitude, RandomCoordsFlag, -(Latitude.x:RandomCoordsFlag.y))
  

#output the file with random coordinates
write.csv(postoffices_randomcoords, "output/us-post-offices-random-coords.csv", row.names=F, na="")
