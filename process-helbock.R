# This is code to take Richard Helbock's dataset of U.S. Post offices and match them to geographic coordinates of places listed in the USGS Board on Geographic Names
# Cameron Blevins (2021)

library(tidyverse)
library(Hmisc)
library(stringdist)
library(fuzzyjoin)
library(data.table)
library(tictoc)

###Read in, clean up Helbock's full database from .mdb file #####
helbock_data_original<- mdb.get("data/Complete_USPO.mdb")
helbock_data<-helbock_data_original
helbock_data<- helbock_data %>% 
  mutate_all(as.character) %>% #convert all columns to string
  mutate_all(trimws) %>% #trim extra whitespace
  mutate(ID=as.numeric(ID)) %>% #convert ID column into number
  rename(Name=POST.OFFICE, State=STATE, Established=Estab, Continuous=to, Discontinued=Disc, StampIndex=S.I) %>%
  mutate(AltName="", OrigName=Name, OrigCounty=County) %>% #creating empty column for altnerative spellings of names
  select(Name, AltName, OrigName, everything())

#Getting rid of parentheses and other characters from names to make it easier to match
helbock_data<-helbock_data %>%
  mutate(Discontinued=ifelse(Discontinued=="Date", NA, Discontinued)) %>% #replacing "Date" values with NA values
  mutate(Discontinued=ifelse(Discontinued=="", NA, Discontinued)) %>% #replacing blank values with NA values
  mutate(Established=ifelse(Established=="", NA, Established)) %>% #replacing blank values with NA values
  mutate(Continuous=ifelse(Continuous=="-", TRUE, FALSE)) %>% #whether a post office was continuous or not - changing values to T/F
  mutate(Name=str_replace(string = Name, pattern=" \\([0-9]\\)", replacement="")) %>% #find pattern of space, parentheses, digit ex. " (1)")
  mutate(Name=str_replace(string = Name, pattern=" \\([CH. ]+\\)", replacement="")) %>% #get rid of all with a C, H, whitetpsace, and period in between parentheses
  mutate(Name=str_replace(string = Name, pattern=" \\(C\\. H\\.\\)", replacement="")) %>% #get rid of all names with "(C. H.)" in them
  mutate(Name=str_replace(string = Name, pattern=" C\\.H\\.", replacement="")) %>% #get rid of all names with "C.H." in them 
  mutate(Name=str_replace(string = Name, pattern=" \\CH\\)", replacement="")) %>% #get rid of all names with "CH)" in them
  mutate(Name=str_replace(string = Name, pattern=" C\\. H\\.\\)", replacement="")) %>%
  mutate(Name=str_replace(string = Name, pattern=" C\\. H\\.", replacement="")) %>%
  mutate(Name=toupper(Name)) %>%
  mutate(AltName=ifelse(str_detect(Name, pattern="\\("), Name, AltName)) %>% #copy contents of Name into Alternate Name column if Name has a parentheses in it
  mutate(AltName=str_replace(AltName, pattern="CENTER\\(RE\\)", replacement="CENTRE")) %>%
  mutate(Name=str_replace(Name, pattern="CENTER\\(RE\\)", replacement="CENTER")) %>%
  mutate(AltName=str_replace(AltName, pattern="CENTRE\\(ER\\)", replacement="CENTER")) %>%
  mutate(Name=str_replace(Name, pattern="CENTRE\\(ER\\)", replacement="CENTRE")) %>%
  mutate(Name=str_replace_all(string= Name, pattern="\\(.*?\\)", replacement="")) %>% #delete anything inside parentheses in original name
  mutate(AltName=str_replace(string=AltName, pattern="\\b[A-Z]+\\b \\(", replacement="")) %>%
  mutate(AltName=str_replace_all(string=AltName, pattern="[()]", replacement="")) %>%
  mutate(AltName=ifelse(str_detect(Name, pattern="^MC ") & AltName=="", str_replace_all(string=Name, pattern="^MC ", replacement="MC"), AltName)) %>% #if a Name starst with "MC C___" then add alternate name of "MCC___"
  mutate(AltName=ifelse(str_detect(Name, pattern=" COURT HOUSE$| COURTHOUSE$| TOWNSHIP$| STATION$") & AltName=="", str_replace_all(string=Name, pattern=" COURT HOUSE$| COURTHOUSE$| TOWNSHIP$| STATION$", replacement=""), AltName)) %>% #if a Name contains "Courthoue" then add alternate name of without the courthoue"
  mutate(AltName=ifelse(str_detect(Name, pattern="'") & AltName=="", str_replace_all(string=Name, pattern="'", replacement=""), AltName)) %>% #if a contains an apostrphe, remove it and add to alternative name
  mutate(AltName=ifelse(AltName=="", NA, AltName)) %>%
  mutate(AltName=toupper(AltName)) %>%
  mutate(Established=str_replace(string=Established, pattern="[-``]", replacement="")) %>% #get rid of negative signs
  mutate(Discontinued=str_replace(string=Discontinued, pattern="[-``]", replacement="")) %>% #get rid of negative signs
  mutate(County=str_replace_all(string=County, pattern="[-]", replacement="")) %>%
  mutate(County=toupper(County)) %>%
  separate(County, c("County1", "County2", "County3"), sep="[/\\\\]") %>% #split any county names that have a slash or blackslash in them
  mutate(County2 = if_else(County1=="CHRISTIAN" & State == "IL", "CLARK", "")) %>% #Helbock mislabeled Clark county as Christian county a bunch, so adding Clark as second county to check
  mutate(County2 = if_else(County1=="NORFOLK" & State == "VA" & County2=="", "CHESAPEAKE", County2)) %>% #confusing county history - momst of Chesapeake used to be Norfolk, so adding it as alternative county
  mutate_all(trimws) %>% #get rid of any extra whitespace
  mutate(ID=as.integer(ID)) %>% #change ID field to an integer
  mutate(Continuous=as.logical(Continuous)) #T/F if the post office was continually operational

rm(helbock_data_original)

######### Processing GNIS file ############

#read in GNIS download of features - this is a list of unique features, each with a unique ID

## NOTE: this is only a sample file used for Github because the full file is too large. Replace this file with the full version: https://dataverse.harvard.edu/api/access/datafile/4491883
gnis_full<-read_delim("data/NationalFile_20210101.txt", delim = "|",col_names = TRUE, escape_double = FALSE, trim_ws = TRUE, progress=TRUE)
gnis_full<-as.data.frame(gnis_full)
gnis_full<- gnis_full %>%
  rename(OldName=FEATURE_NAME, Feature.Class=FEATURE_CLASS, State=STATE_ALPHA, County=COUNTY_NAME, Latitude=PRIM_LAT_DEC, Longitude=PRIM_LONG_DEC)

#Taking in the full name list (includes ALTERNATE names for features) - this is a list of all names, including altnerate names for the same feature
#then joining it with the GNIS data (lat, long, etc.) to create a big dataframe, with repeated FEATURE ID's in them)

## NOTE: this is only a sample file used for Github because the full file is too large. Replace this file with the full version: https://dataverse.harvard.edu/api/access/datafile/4491882
all_gnisnames_original<-read_delim(file="data/AllNames_20210101_nocitation.txt", delim = "|", col_names = TRUE, escape_double = FALSE, trim_ws = TRUE, progress=TRUE) #escape_double is to handle quote marks within names (othewrwise gets messed up)
all_gnisnames_original<-as.data.frame(all_gnisnames_original)
#only select first two columns of data, clean up, and join it to the main GNIS dataframe
all_gnisnames<-all_gnisnames_original %>%
  select(FEATURE_ID:FEATURE_NAME) %>%
  rename(Name=FEATURE_NAME) %>%
  left_join(gnis_full, by="FEATURE_ID")
rm(all_gnisnames_original)
rm(gnis_full)

#feature types you want to try to match
features<-c("Post Office", "Populated Place", "Locale", "Mine", "Cemetery", "School", "Military", "Cape", "Civil", "Church", "Census")

#take a subset of all the GNIS features that are part of features list - ex. post offices, etc. and process them so they're ready for matching
gnis<- all_gnisnames %>%
  filter(Feature.Class %in% features) %>%
  mutate(OrigName=Name) %>%
  mutate(Name=toupper(Name)) %>%
  mutate(OrigCounty=County) %>%
  mutate(County=toupper(str_replace_all(string=County, pattern="\\(.*?\\)", replacement=""))) %>%
  select(-c(STATE_NUMERIC, COUNTY_NUMERIC)) %>%
  filter(PRIMARY_LAT_DMS != "Unknown" | Latitude != 0) #remove ones that don't have coordinates attached to them
rm(all_gnisnames)

#cleaning up the Name field of the GNIS database
#list of words to delete from the Name field of GNIS database
delete_words<-c(" ELEMENTARY SCHOOL", " MIDDLE SCHOOL", " HIGH SCHOOL", " POST OFFICE", " CEMETERY", " SCHOOL", "^TOWN OF ", " CENSUS DESIGNATED PLACE", " \\(HISTORICAL\\)")
for(w in delete_words){
  print(w);
  gnis<- gnis %>%
    mutate(Name=str_replace_all(string=Name, pattern=w, replacement=""))
}
gnis<- gnis %>%
  mutate(Name=ifelse(str_detect(string=Name, pattern="^TOWNSHIP"), yes = Name, no= str_replace_all(string=Name, pattern="TOWNSHIP", replacement=""))) %>%
  mutate_all(trimws)

#only select a subset of columns
gnis<- gnis %>% #filter(Name!="" & PRIMARY_LAT_DMS != "Unknown") %>%
  select(FEATURE_ID:County, OrigName, OrigCounty, Latitude, Longitude, ELEV_IN_M, ELEV_IN_FT)

#### Cleaning Helbock by comparing to GNIS data to look for typos, etc.

#flag problems - when years aren't 4 characters long, when length of state is more than 2 characters
helbock_data_problems<-helbock_data %>% 
  mutate(Problem = FALSE) %>%
  mutate(Problem = case_when(str_length(Established) != 4 | (as.numeric(Established)<1639 | as.numeric(Established)>2000) ~ TRUE, TRUE ~ Problem)) %>%
  mutate(Problem = case_when((str_length(Discontinued)!= 4 & !is.na(Discontinued)) ~ TRUE, TRUE ~ Problem)) %>%
  mutate(Problem = case_when(str_length(State) > 2 ~ TRUE, TRUE ~ Problem)) %>%
  filter(Problem==TRUE)
#export CSV of full Helbock data with problems flagged
write.csv(helbock_data_problems, file = "analytics/Helbock_Data_Problems.csv", row.names = FALSE)

#looking for counties that don't line up between the two datasets
helbock_counties<-helbock_data %>%
  group_by(State, County1) %>%
  summarise(n=n())
gnis_counties<-gnis %>%
  group_by(State, County) %>%
  summarise(n=n())
problem_counties <- helbock_counties %>%
  full_join(gnis_counties, by=c("State", "County1" = "County")) %>%
  filter(is.na(n.x) | is.na(n.y)) #look at counties from one dataset that don't show up in the other
write.csv(problem_counties, "analytics/problem_counties.csv")

#changing names of counties - using a CSV file where I manually started going through and fixing mistakes
counties_change<-read.csv("analytics/problem_counties_replacements.csv", header = TRUE, stringsAsFactors = FALSE)
counties_change <- counties_change %>%
  filter(ToDo=="no") %>% #look only at the counties that I've manually found replacement values for - ToDo = yes are ones haven't done yet
  select(State, County1, County1_Replacement, County2_Replacement)
#perform joins to lookup and change problem counties in the helbock dataframe
helbock_data<-helbock_data %>%
  left_join(counties_change, by = c("State", "County1")) %>% #temporarily add the replacement county values as new columns (if you don't have a match you'll have NA values)
  mutate(County1=ifelse(!is.na(County1_Replacement), yes=County1_Replacement, no=County1)) %>% #replace county values
  mutate(County1 = replace(County1, str_detect(County1, " ANA"), (gnis %>% filter(str_detect(County, " ANA")))[1,6])) %>% #replacing n character for Dona Ana so it matches GNIS character
  mutate(County2=ifelse(!is.na(County2_Replacement), yes=County2_Replacement, no=County2)) %>% #replace county values
  select(-c(County1_Replacement, County2_Replacement)) %>%
  mutate(County2=ifelse(County2=="", yes=NA, no=County2)) #replace empty values in Column 2 with NA's

####### MATCHING ROUNDS #########

##initializing the dataframes
gnis_tomatch<-gnis #dataframe of GNIS all features you're going to match
po_tomatch<-helbock_data #dataframe of Helbock's data that you're going to try and find matches for in GNIS data
po_matched<-po_tomatch[0,] #empty dataframe that you're going to fill with matched values

#####MATCHING PHASE I: Look up Name, County, State in GNIS across multiple features #####

#taking just a subset of data for testing purposes - comment out later for full matching
#gnis_tomatch <- gnis %>%
#   filter((State=="CO" | State=="AZ"))
# po_tomatch<-helbock_data %>%
#   filter(State=="AK" | State=="AZ") %>%
#   sample_n(120)
#po_tomatch<-helbock_data %>% filter(!(ID %in% po_matched$ID)) #in case you are starting with a subset

#function to match any individual name, county, and state combination, then add results to external dataframe and winnow down the dataframe you want to look up
#send in three columns: df1 = Post OFfices you want to match, df2 is GNIS dataframe, df3 is a copy of Post Offices you want to match that you'll update
matchfun<-function(df1, df2, df3){
  df1 <- df1 %>% 
    rename(Name=1, County=2, State=3) %>% #rename columns
    filter(!(ID %in% po_matched$ID)) %>% #if the Post Office has not already been matched
    left_join(df2, by=c("Name", "County", "State")) %>% #join post office dataframe to GNIS dataframe based on full name, county and state matches
    mutate(Match=ifelse(is.na(FEATURE_ID), FALSE, TRUE)) %>% #add a column Match to flag ones you've found
    select(-c(OldName)) #get rid of original GNIS name (used for reference, don't need to attach it to post office data)
  names(df1) <- paste0("GNIS.", names(df1)) #add a prefix to all the column names
  temp_matched <- df3 %>% #join to the other Post Office dataframe to createa  temporary dataframe of matched values
    left_join(df1, by=c("ID"="GNIS.ID")) %>%
    filter(GNIS.Match ==TRUE)
  po_matched<<- po_matched %>% ## double carrot (<<) changes GLOBAL variable of po_matched outside of this function - adding new rows to dataframe of running matches
    bind_rows(filter(temp_matched, !(ID %in% po_matched$ID))) %>%#add matches to the matched dataframe so long as the post office isn't already in there
    #next few lines gets rid of duplicates matches by only taking the first one you matched (I think)
    group_by(ID) %>% 
    filter(row_number()==1) %>%
    ungroup()
  po_tomatch<<- po_tomatch %>% #winnow down the running dataframes that you still have to match
    filter(!(ID %in% po_matched$ID))
}

###function to match post offices that don't have a county, just a name and a state (mostly Alaska)
matchfun_bynamestate<-function(df1, df2, df3){
  df1 <- df1 %>% 
    rename(Name=1, State=2) %>% #rename columns
    filter(!(ID %in% po_matched$ID)) %>% #if the Post Office has not already been matched
    left_join(df2, by=c("Name", "State")) %>% #join post office dataframe to GNIS dataframe based on full name, county and state matches
    mutate(Match=ifelse(is.na(FEATURE_ID), FALSE, TRUE)) %>% #add a column Match to flag ones you've found
    select(-c(OldName)) #get rid of original GNIS name (used for reference, don't need to attach it to post office data)
  names(df1) <- paste0("GNIS.", names(df1)) #add a prefix to all the column names
  temp_matched <- df3 %>% #join to the other Post Office dataframe to create a temporary dataframe of matched values
    left_join(df1, by=c("ID"="GNIS.ID")) %>%
    filter(GNIS.Match ==TRUE)
  po_matched<<- po_matched %>% ## double carrot (<<) changes GLOBAL variable - adding new rows to dataframe of running matches
    bind_rows(filter(temp_matched, !(ID %in% po_matched$ID))) %>%#add matches to the matched dataframe so long as the post office isn't already in there
    #next few lines gets rid of duplicates matches by only taking the first one you matched (I think)
    group_by(ID) %>% 
    filter(row_number()==1) %>%
    ungroup()
  po_tomatch<<- po_tomatch %>% #winnow down the running dataframes that you still have to match
    filter(!(ID %in% po_matched$ID))
}

#going to go through a list of GNIS features, sequentially, trying to first match post offices, then populated places, etc. Matching various combinations of names and counties from Helbock's database.
tic()
for(f in features){
  print(f);
  gnis_tomatch<-filter(gnis, Feature.Class==f);
  #po_tomatch <-filter(po_tomatch, !(ID %in% po_matched$ID)); #use if you don't want to try to match over the full list of post offices, but only unmatched ones
  matchfun(select(po_tomatch, Name, County1, State, ID), gnis_tomatch, po_tomatch); #try to match on main name and county
  #Alaksa post offices don't have a county, sending to separate function
  justnamestate<-po_tomatch %>% filter(State=="AK") %>% select(Name, State, ID); 
  matchfun_bynamestate(justnamestate, gnis_tomatch, po_tomatch);
  justnamestate_altname<-po_tomatch %>% filter(!is.na(AltName) & State=="AK") %>% select(AltName, State, ID);
  matchfun_bynamestate(justnamestate, gnis_tomatch, po_tomatch);
  #looking at post offices that didn't get a match on their name, but have an alternative name to check
  othercombos<-po_tomatch %>% filter(!is.na(AltName)); 
  matchfun(select(othercombos, AltName, County1, State, ID), gnis_tomatch, po_tomatch);
  othercombos<-po_tomatch %>% filter(!is.na(County2)); #trying to match on an alternative county
  matchfun(select(othercombos, Name, County2, State, ID), gnis_tomatch, po_tomatch);
  othercombos<-po_tomatch %>% filter(!is.na(AltName));
  matchfun(select(othercombos, AltName, County2, State, ID), gnis_tomatch, po_tomatch);
}
#if you've found a match, it means the levenshtein distance score = 1 (a full match), so adding a column 
po_matched<-po_matched %>%
  mutate(GNIS.Dist=1) %>%
  mutate(Continuous=as.logical(Continuous))
toc(log=TRUE) #end timer and store to log
endtime<-unlist(tic.log(format=TRUE)) #create character variable has the elapsed time
tic.clear()
tic.clearlog()

write(paste0("Matching data for Round 1 of geolocating Helbock data with GNIS data. Processed on ", Sys.time(), "\n",
  "Time: ", endtime, "\n",
  "Number matched: ", nrow(po_matched), "\n", 
  "Number remaining to match: ", nrow(po_tomatch), "\n",
  "Percentage matched this round: ", nrow(po_matched)/(nrow(po_tomatch)+nrow(po_matched))*100), 
  paste0("analytics/round1_analytics_", Sys.Date(), ".txt"))
paste0("Percentage matched this round: ", nrow(po_matched)/(nrow(po_tomatch)+nrow(po_matched))*100, "%")

#using these to save data that you've already run so you don't have to re-run all the matching (cpu intensive)
po_matched_round1<-po_matched
po_tomatch_round1<-po_tomatch

##write to a file = ****** ONLY use this when you're doing the full dataset, otherwise will overwrite ****
write.csv(po_matched_round1, "analytics/round1.csv", row.names = F)


##### ROUND 2 #######
#now that we've tried doing more exact matches with GNIS features, we're going to modify specific GNIS feature names to cast a wider net 
#- ex. looking for Populated Places but removing the "TOWN" from "___ TOWN" within only Populated Places

####initializing dataframes - use this if you're starting from scratch
po_matched_start<-po_matched_round1 #this creates a dataframe of just post offices that weren't matched at the start of Round 2
po_matched <- po_matched_round1 #this is the main dataframe of matched post offices that you're going to add to
po_matched_round2<-po_matched[0,] #initiatilizing empty dataframe of just post offices you match in this round
po_tomatch_round2 <- helbock_data %>% filter(!(ID %in% po_matched$ID)) #pulling in post offices you need to match
gnis_tomatch<-gnis #all GNIS features

#set of matching functions you run through for every post office, sending in two dataframes: a subset of the GNIS features and the remaining post offices to match
matchingcombos<-function(df_gnis, df_pos){
  matchfun(select(df_pos, Name, County1, State, ID), df_gnis, df_pos); #try to match on main name and county
  othercombos<-df_pos %>% filter(!is.na(AltName)); #if there's an alternative name
  matchfun(select(othercombos, AltName, County1, State, ID), df_gnis, df_pos); #try to match on alt name and county1
  othercombos<-df_pos %>% filter(!is.na(County2)); #if there's an alternative county
  matchfun(select(df_pos, Name, County2, State, ID), df_gnis, df_pos); #try to match on main name and county2
  othercombos<-df_pos %>% filter(!is.na(AltName) & !(is.na(County2))); #if there's an alternative name and an altenrative county
  matchfun(select(df_pos, AltName, County2, State, ID), df_gnis, df_pos); #try to match on alt name and county2
}

tic()
#Populated Places
pattern_list<-" TOWN$"
gnis_tomatch<-gnis %>%
  filter(Feature.Class == "Populated Place") %>%
  filter(str_detect(Name, pattern_list)) %>% #looking only at features that end with " TOWN"
  mutate(Name = str_replace(Name, pattern_list, "")) #deleting " TOWN"
po_tomatch_round2 <- helbock_data %>% filter(!(ID %in% po_matched$ID))
matchingcombos(gnis_tomatch, po_tomatch_round2)

#Civil
pattern_list<-"^TOWNSHIP OF |^CITY OF |^BOROUGH OF | COUNTY$| INDIAN RESERVATION$| RESERVATION$"
gnis_tomatch <- gnis %>%
  filter(Feature.Class == "Civil") %>%
  filter(str_detect(Name, pattern_list)) %>% #looking only at features that end with " COUNTY"
  mutate(Name = str_replace_all(Name, pattern_list, "")) #deleting " COUNTY" "TOWNSHIP OF " ETC.
po_tomatch_round2 <- helbock_data %>% filter(!(ID %in% po_matched$ID))
matchingcombos(gnis_tomatch, po_tomatch_round2)

#Mines
pattern_list<-" MINE$"
gnis_tomatch <- gnis %>%
  filter(Feature.Class == "Mine") %>%
  filter(str_detect(Name, pattern_list)) %>% #looking only at features that end with " MINE"
  mutate(Name = str_replace_all(Name, pattern_list, "")) #deleting " MINE"
po_tomatch_round2 <- helbock_data %>% filter(!(ID %in% po_matched$ID))
matchingcombos(gnis_tomatch, po_tomatch_round2)

#Churches
pattern_list<-" UNITED METHODIST| FIRST BAPTIST| BAPTIST| CATHOLIC| EPISCOPAL| METHODIST| PRESBYTERIAN| LUTHERAN| MENNONITE| GOSPEL| PENTECOSTAL| CHRISTIAN| CONGREGATIONAL| CHURCH$"
gnis_tomatch <- gnis %>%
  filter(Feature.Class == "Church") %>%
  filter(str_detect(Name, pattern_list)) %>% 
  mutate(Name = str_replace_all(Name, pattern_list, ""))
po_tomatch_round2 <- helbock_data %>% filter(!(ID %in% po_matched$ID))
matchingcombos(gnis_tomatch, po_tomatch_round2)

#Schools
pattern_list<-" CHRISTIAN ACADEMY$| MILITARY ACADEMY$| CHILDREN'S ACADEMY$| JUNIOR ACADEMY$| GIFTED ACADEMY$| ACADEMY$"
gnis_tomatch <- gnis %>% 
  filter(Feature.Class=="School") %>% 
  filter(str_detect(Name, pattern_list)) %>%
  mutate(Name = str_replace_all(Name, pattern_list, "")) #deleting " ACADEMY" variants
po_tomatch_round2 <- helbock_data %>% filter(!(ID %in% po_matched$ID))
matchingcombos(gnis_tomatch, po_tomatch_round2)

#Locales
pattern_list<-" HISTORICAL SITE$| VILLAGE$| COUNTRY CLUB$| RECREATION CENTER$| SHOPPING CENTER$| COUNTRY CLUB$| INDUSTRIAL PARK$| MALL$| RANCH$| CAMPGROUND$| PICNIC GROUND$| LANDING$| RAILROAD STATION$| FARM$"
gnis_tomatch <- gnis %>% 
  filter(Feature.Class=="Locale") %>%
  filter(str_detect(Name, pattern_list)) %>%
  mutate(Name = str_replace_all(Name, pattern_list, ""))
po_tomatch_round2 <- helbock_data %>% filter(!(ID %in% po_matched$ID))
matchingcombos(gnis_tomatch, po_tomatch_round2)

#Capes
pattern_list<-"^POINT | POINT$"
gnis_tomatch <- gnis %>%
  filter(Feature.Class == "Cape") %>%
  filter(str_detect(Name, pattern_list)) %>% #looking only at features that end with " POINT"
  mutate(Name = str_replace_all(Name, pattern_list, "")) #deleting " POINT"
po_tomatch_round2 <- helbock_data %>% filter(!(ID %in% po_matched$ID))
matchingcombos(gnis_tomatch, po_tomatch_round2)

#fill dataframe with just post offices that you've matched this round
po_matched_round2<-po_matched %>%
  filter(!(ID %in% po_matched_start$ID))

#remaining post offices that weren't matched after round 2
po_tomatch_round2 <- helbock_data %>% filter(!(ID %in% po_matched$ID))

#rm(gnis_tomatch)

toc(log=TRUE) #end timer and store to log
endtime<-unlist(tic.log(format=TRUE)) #create character variable has the elapsed time
tic.clear()
tic.clearlog()

write(paste0("Matching data for Round 2 of geolocating Helbock data with GNIS data. Processed on ", Sys.time(), "\n",
             "Time: ", endtime, "\n",
             "Total number matched so far: ", nrow(po_matched), "\n", 
             "Total remaining to match: ", nrow(po_tomatch_round2), "\n",
             "Number matched this round: ", nrow(po_matched_round2), "\n",
             "Percentage matched this round: ", nrow(po_matched_round2)/(nrow(helbock_data))*100), 
      paste0("analytics/round2_analytics_", Sys.Date(), ".txt"))
paste0("Percentage matched this round: ", nrow(po_matched_round2)/(nrow(helbock_data)-po_matched_round1)*100, "%")

po_matched<-po_matched %>%
  mutate(GNIS.Dist=1)

##write to a file = only use this when you're doing the full dataset, otherwise will overwrite ****
write.csv(po_matched_round2, "analytics/round2.csv", row.names = F)

#### MATCHING PHASE 3: Fuzzy matching for Names of post offices you didn't match in first round

#function to take in name, state, county and do fuzzy matching based on name
fuzzy_matchfun <- function(df1, df2, minmatch){
  print(paste0("Checking name field: ", names(df1)[1], ", and County field: ", names(df1)[2]));
  print(paste0("Number of records checking for feature class ", f, ": ", nrow(df1)));
  df1 <- rename(df1, Name=1, County=2, State=3)
  for (rownum in 1:nrow(df1)){
    if (rownum>nrow(df1)){break} #if you hit the end of hte dataframe
    temp_row<-df1[rownum,]; #looping through dataframe of post offices by index number
    if (is.na(temp_row$Name)) {next};
    name_length<-as.integer(str_length(temp_row$Name)); #length of name in characters
    max_dist_int<-as.integer(name_length-(name_length*minmatch)); #calculate the distance metrics for matching names
    #if (name_length <= 4) {next} #skip over words that are only four characters long or less (too a high chance for false matches)
    gnis_tomatch_temp<-gnis_tomatch[0,]; #initializes an empty dataframe
    #select only GNIS features for the state and county of this post office
    gnis_tomatch_temp<-gnis_tomatch %>%
      filter(State==temp_row$State & County==temp_row$County)
    #append a prefix of GNIS to the GNIS dataframe - makes it easier to join these fields to the post office datafrmae
    names(gnis_tomatch_temp) <- paste0("GNIS.", names(gnis_tomatch_temp));
    #get a datafrmae that's only comprised of the Name and ID of the post office, then do a fuzzy match with the GNIS dataframe to look for matches, appending a distance column that's the number of characters away
    holder_df<-temp_row %>%
      select(Name, ID) %>%
      stringdist_inner_join(gnis_tomatch_temp, by=c(Name="GNIS.Name"), method="lv", distance_col="distance") #using levenshtein distance, defined by the distance column
    #if (nrow(holder_df)>1) {print(holder_df)} #print if you are getting more than one match
    if (nrow(holder_df)>0) { #if you found at least one fuzzy match
      holder_df<-holder_df %>% 
        mutate(GNIS.Dist=((name_length-distance)/name_length)) %>% #calculate the string distance as a percentage of the length ofhte post office string
        select(-c(distance, GNIS.OldName)) %>%
        filter(GNIS.Dist >=minmatch) %>%
        filter(!((str_sub(Name, 1, 4)=="EAST" & str_sub(GNIS.Name, 1, 4)=="WEST") | (str_sub(Name, 1, 4)=="WEST" & str_sub(GNIS.Name, 1, 4)=="EAST"))) %>% #This is removing matches that are accidentally matching "East __" and "West __"
        filter(!(as.integer(str_length(Name))<=4 & (str_sub(Name, 1, 1)!=str_sub(GNIS.Name, 1, 1)))) %>% #remove any matches in which the length of the name is  4 letters or less AND it doesn't start with the same letter as the GNIS match - ex. "FERN" and "LERN"
        #only return the highest scoring match
        arrange(desc(GNIS.Dist)) %>% #sort it descending by GNIS score and then alphabetically by Post Office Name
        group_by(ID) %>% 
        filter(row_number()==1) %>% #take only the highest sorted one (one with highest GNIS score)
        ungroup() %>%
        #add a GNIS.Match column if you found a match
        mutate(GNIS.Match=ifelse(is.na(GNIS.FEATURE_ID), FALSE, TRUE)) %>%
        select(-Name) %>% #prepping it for a join - want to drop the name since you're going to grab it from post office records using the ID key
        left_join(po_tomatch, by=c("ID")) #get all the other columns associated with that post office record 
      #if the post office record is not already in the GLOBAL successfully matched df, then add it
      po_matched_round3<<- po_matched_round3 %>%
        bind_rows(filter(holder_df, !(ID %in% po_matched_round3$ID)))
    }
    #remove the records you've already matched from the GLOBAL dataframe of unmatched records
    po_tomatch<<- po_tomatch %>%
      filter(!(ID %in% po_matched_round3$ID))
  }
}

#use this for full data
po_tomatch <- helbock_data %>% filter(!(ID %in% po_matched$ID))
gnis_tomatch<-gnis

## define samples of incoming datasets for debugging- comment out for full dataset
# po_tomatch<-helbock_data %>% filter(!(ID %in% po_matched$ID)) %>%
#   sample_n(50)
# gnis_tomatch <- gnis %>%
#   filter(Name %in% c("HOME VALLEY", "DAYSBOROUGH", "DAYSBORO", "GALLION", "CALION", "LINE", "PRINDLE", "TOOELLE"))
# po_tomatch<-po_tomatch %>% 
#   filter(ID %in% c("15893", "108367","66960","141858", "146143")) #getting specific ones for testing purposes
# gnis_tomatch <- gnis %>%
#   #filter((State=="CO" | State=="AZ") & Feature.Class == "Populated Place")
#   filter(Feature.Class == "Populated Place")

minmatch<-0.75 ###minimum matching score (out of 100) you want to try and match
po_matched_round3<-po_matched[0,] #empty dataframe that you're going to add new matches into

#### this is where you actually send in matches - very CPU intensive, going to take awhile to run
tic("start")
for (f in features){
  tic("feature")
  print(paste0("*******Feature Class: ", f, "*******"));
  gnis_tomatch<-gnis %>%
    filter(Feature.Class==f)
  fuzzy_matchfun(select(po_tomatch, Name, County1, State, ID), po_tomatch, minmatch) #send post offices for fuzzy matching
  fuzzy_matchfun(po_tomatch %>% filter(!(is.na(AltName) | AltName == "")) %>% select(AltName, County1, State, ID), po_tomatch, minmatch) #send only post offices that has an alternative name
  fuzzy_matchfun(po_tomatch %>% filter(!(is.na(County2) | County2 == "")) %>% select(Name, County2, State, ID), po_tomatch, minmatch) #send only post offices that have an altnerative county
  fuzzy_matchfun(po_tomatch %>% filter(!(is.na(AltName) | AltName == "")) %>% filter(!(is.na(County2) | County2 == "")) %>% select(AltName, County2, State, ID), po_tomatch, minmatch) #send only post offices that have an alternative name and an altenrative county
  print(paste0("******Successfully matched: ", nrow(po_matched_round3)));
  print(paste0("******Still need to match: ", nrow(po_tomatch)));
  toc()
}
toc(log=TRUE) #end timer and store to log
endtime<-unlist(tic.log(format=TRUE)) #create character variable has the elapsed time
tic.clear()
tic.clearlog()

po_matched_round3_backup<-po_matched_round3 #just being careful since this is so CPU intensive don't want to run again
po_tomatch_round3<-po_tomatch

nummatched_overall<-nrow(po_matched_round1)+nrow(po_matched_round2)+nrow(po_matched_round3)
numremaining_overall<-nrow(helbock_data)-nummatched_overall
percentagematched_overall<-nummatched_overall/nrow(helbock_data)
write(paste0("Matching data for Round 3 of geolocating Helbock data with GNIS data. Processed on ", Sys.time(), "\n",
             "Using a minimum fuzzy match score: ", minmatch, " (Levenshtein distance method).\n",
             "Time: ", endtime, "\n",
             "Number matched this round: ", nrow(po_matched_round3), "\n", 
             "Percentage of all post offices matched this round: ", round((nrow(po_matched_round3)/nrow(helbock_data))*100, digits=3), "\n", 
             "Number remaining to match after this round: ", nrow(po_tomatch), "\n",
             "Percentage matched within this round: ", nrow(po_matched_round3)/(nrow(po_tomatch)+nrow(po_matched_round3))*100, "\n",
             "Overall number matched: ", nummatched_overall, "\n", 
             "Overall remaining to match: ", numremaining_overall, "\n",
             "Percentage matched overall: ", round(percentagematched_overall*100, digits=3)),
      paste0("analytics/round3_analytics_", Sys.Date(), ".txt"))

write.csv(po_matched_round3, "analytics/round3.csv", row.names=F)
write.csv(po_tomatch_round3, "analytics/needtomatch-afterround3.csv", row.names=F, na="")

po_matched<-bind_rows(po_matched_round1, po_matched_round2, po_matched_round3) #all of the post offices that have been matched

###### EXPORT THE DATA

#export csv files with temporary data of matches and the full dataset (but not with all the added columns yet)
write.csv(po_matched, "output/matched_03_14_2021.csv", row.names=F, na="")
fulldata<-po_matched %>% 
  bind_rows(po_tomatch) %>%
  mutate(GNIS.Match=ifelse(is.na(GNIS.Match), FALSE, TRUE)) #flag non-matches with FALSE for GNIS.Match
write.csv(fulldata, "output/fulldata_03_14_2021.csv", row.names=F, na="")

## Export your full dataset with renamed, reordered, and additional columns

fulldata<-read.csv("output/fulldata_03_14_2021.csv", stringsAsFactors = F)
fulldata<-fulldata %>%
  mutate_all(trimws) %>%
  #mutate(Established=as.integer(Established), Discontinued=as.integer(Discontinued), ID=as.integer(ID))
  mutate_at(c("Established", "Discontinued", "ID", "GNIS.FEATURE_ID", "GNIS.ELEV_IN_M"), as.integer) %>%
  mutate_at(c("GNIS.Latitude", "GNIS.Longitude", "GNIS.Dist"), as.numeric) %>%
  mutate_at(c("Continuous", "GNIS.Match"), as.logical)

export_data<- fulldata %>%
  mutate(Latitude = GNIS.Latitude, Longitude=GNIS.Longitude) %>%
  mutate(Coordinates=ifelse(GNIS.Match==TRUE, TRUE, FALSE)) %>%
  mutate(Duration = as.numeric(Discontinued)-as.numeric(Established)) %>%
  select(Name, AltName, OrigName, State, County1, County2, County3, OrigCounty, Established, Discontinued, Continuous, StampIndex, ID, Coordinates, Duration, GNIS.Match, everything(), -(GNIS.ELEV_IN_FT)) %>% #reorder columns
  arrange(ID)
write.csv(export_data, "output/us-post-offices.csv", row.names=F, na="")

