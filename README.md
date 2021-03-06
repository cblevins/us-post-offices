# US Post Offices

## Cameron Blevins (March 2021)

This repository contains the code used by Cameron Blevins to create the [US Post Offices dataset](https://cblevins.github.io/us-post-offices/), which contains records about 166,140 post offices that operated in the United States between 1639-2000. Richard Helbock (1938-2011) conducted archival research to compile historical information about these post offices. The code in this repository was written by Blevins in order to geocode, or find geographical coordinates, for as many records from Helbock's dataset as possible. The following README file describes this geocoding process. It took place in two successive stages: a) using the [Geographic Names Information System (GNIS) Domestic Names](https://www.usgs.gov/core-science-systems/ngp/board-on-geographic-names/domestic-names) database as a historical gazetteer to geocode a majority of post offices, and b) assigning semi-random location coordinates to the remaining post offices based on the county in which they operated. Refer to the [US Post Offices Data Biography](https://cblevins.github.io/us-post-offices/data-biography) for a discussion of the resulting dataset. 

### Files and Folders

#### Main Project Files:

- **`us-post-offices.csv`:** The main tabular dataset generated from geocoding Helbock's data using the GNIS database. *Note: this file contains many records with missing geographical coordinates. Refer to documentation below and the [US Post Offices Data Biography](https://cblevins.github.io/us-post-offices/data-biography) before using this data.*
- **`us-post-offices-random-coords.csv`**: Alternative dataset to `us-post-offices.csv` containing semi-random coordinates assigned to any post offices that were not successfully geolocated using the GNIS database. *Note: Refer to documentation below and the [US Post Offices Data Biography](https://cblevins.github.io/us-post-offices/data-biography) for more details before using this data.*
- `process-helbock.r`: R file for geocoding Helbock's data using the GNIS database approach.
- `assign-random-coordinates.r`: R file used for assigning semi-random coordinates to any post offices that were not geocoded using the GNIS database approach.
- `us-post-offices-data-dictionary.csv`: Detailed explanations for each of the fields in `us-post-offices.csv` and `us-post-offices-random-coords.csv`.
- The `/docs/` folder contains a [Github Pages](https://cblevins.github.io/us-post-offices) site with more information about the dataset.

#### Files in `data` folder:

- `Complete_USPO.mdb`: Original Microsoft Access database of post office records compiled by Richard Helbock.
- `NationalFile_20210101.txt`: Tabular data containing all official domestic GNIS features for the United States, downloaded in March 2021.
  - This was too large a file to host on Github, so I'm only providing the first 100,000 rows from this file for testing and replication purposes. If you want to run the geocoding process using a full file, replace this file with [a full updated version from GNIS](https://geonames.usgs.gov/docs/stategaz/NationalFile.zip) or [the original file I used from Harvard Dataverse](https://doi.org/10.7910/DVN/NUKCNA)
- `AllNames_20210101_nocitation.txt`: Tabular data containing variant names for GNIS domestic features, downloaded in March 2021.
  - This was too large a file to host on Github, so I'm only providing the first 100,000 rows from this file for testing and replication purposes. If you want to run the geocoding process using a full file, replace this file with [a full updated version from GNIS](https://geonames.usgs.gov/docs/stategaz/AllNames.zip) or [the original file I used from Harvard Dataverse](https://doi.org/10.7910/DVN/NUKCNA).
  - If you are using an updated version from GNIS, note that the last two columns include a lot of citation text that makes it quite large. To reduce its size, I lopped off the last two columns using the shell command: `cut -d '|' -f 1-3,5 AllNames_20210101.txt > AllNames_20210101_nocitation.txt`.   
- `random-coordinates-150-per-county.csv`: Tabular data of coordinates for points that were randomly distributed within every US county using QGIS's Random Points Inside Polygons tool.

#### Files in `analytics` folder:

The `analytics` folder contains files that were generated during each phase of the geocoding process. They capture information about how many records were successfully matched during each round, along with temporary data files that can be used as placeholders to back up data between matching rounds.

#### Files in `output` folder:

- `fulldata_[somedate].csv`: Any files with this naming convention were generated during the geocoding process to serve as a temporary holding file before generating the final dataset.
- `matched_[somedate].csv`: Any files with this naming convention were generated during the geocoding process to serve as a temporary holding file for successfully geolocated post offices before generating the final dataset.

## Data Processing Steps: GNIS Geocoding

### Overview of Matching Process

I used a historical gazetteer approach with the [Geographic Names Information System (GNIS) Domestic Names](https://www.usgs.gov/core-science-systems/ngp/board-on-geographic-names/domestic-names) collected by the U.S. Board on Geographic Names under the U.S. Geological Survey. This dataset includes several million named features from the United States, categorized into Feature Classes ([defined here](https://geonames.usgs.gov/apex/f?p=gnispq:8:0:::::)). The script for geocoding using the GNIS database can be found in `process-helbock.R`. 

The basic approach was to look for matches between post offices in Helbock's dataset that have the same Name, State, and County as a feature in the GNIS database. Some post offices have multiple counties listed, so I needed to check multiple combinations of Name + State + County. I used a hierarchy of GNIS features that acted as a sequential series of filters to pass post office records through, taking the first full match and removing that post office from the list of remaining records to try and match. This was based on descending likelihood that a particular kind of GNIS feature would be the correct match for a post office (versus a false positive match). The order was determined through an examination of the [GNIS Feature Classes](https://geonames.usgs.gov/apex/f?p=gnispq:8:0:::::) and through trial and error.

1.  Post Office
2.  Populated Place
3.  Locale
4.  Mine
5.  Cemetery
6.  School
7.  Military
8.  Cape
9.  Civil
10. Church
11. Census

The geocoding process took place in three phases, with each phase casting a wider net of potential matches (and therefore having a higher chance of false positive matches). Phase 1 looked for an exact match between Helbock's post office name and the names of GNIS features. Phase 2 tweaked some of the GNIS feature names within each feature class to cast a wider net of potential matches. Phase 3 used "fuzzy matching" to try and find matches between post office names and GNIS features names, even if they were spelled slightly differently.

### Prepping the Data

1.  Read in Helbock's Dataset and do some basic cleaning (whitespace, spelling variations, adding alternative names to look up, etc.)
2.  Read in the GNIS National file - name, state, county, coordinates, etc. for features.
3.  Read in the GNIS AllNames file - contains variants on names for the same GNIS feature
4.  Join the National and AllNames dataframes so that each record contains option to match multiple names
5.  Clean up the joined GNIS dataframe to make it easier to find matches (ex. deleting "ELEMENTARY SCHOOL" from a feature name) and remove any GNIS records that have unknown geographical coordinates.
6.  Do a basic comparison of unique values across the two datasets and then manually clean up some of these discrepancies, especially counties that are spelled differently by Helbock vs. GNIS.

#### Phase 1: Full Matching

Phase 1 tried to find "strict" matches between Helbock's post offices and GNIS features - ie. an identical Name, County, and State.

I defined a series of functions to ingest a post office Name, County, and State and try to match all three of those fields in the GNIS database. Note that Alaska is a separate function that matches only two fields (Name and State) because there were no Alaska counties in Helbock's dataset. An individual post office runs through these functions four times, passing in alternate post office names and any post offices that have multiple counties.

I created a running dataframe of post offices that have not yet been matched. Within each GNIS feature class (ex. Post Office, Populated Place, etc.), I pass the post office dataframe and the GNIS dataframe for that feature into my set of matching functions. Any post offices that are matched are removed from the dataframe of post offices remaining to be matched. This is then repeated for set of GNIS feature class. At the end of Phase 1 I had a subset of Helbock's post offices that had full matches - ie. the Name, State, and County were matched with a GNIS record and assigned coordinates from the GNIS dataset.

On March 14, 2021, Phase 1 found **103,220 matches**, or **62.13%** of the post offices in Helbock's dataset.

#### Phase 2: Targeted Matching

Phase 2 took a more tailored approach by altering the name field of specific GNIS Feature Class. For instance, many Populated Place feature classes have a Name field that starts with "Township of \_\_\_\_". Phase 2 removes the string "Township of " from all Populated Place GNIS features and then tries to match Helbock's remaining unmatched post offices with these cleaned up Populated Place features. It does similar string modifications for other GNIS feature classes. The reason I didn't do this in Round 1 is because I don't want to accidentally miss matches, just in case the full name in Helbock's dataset might match the longer original Name field in the GNIS dataset. Once again, if a match is found for a post office, it is removed from the running list of post offices that need matches.

On March 14, 2021, Phase 2 found **2,789 matches**, or **1.68%** of the total post offices in Helbock's dataset.

#### Phase 3: Fuzzy Matching

Phase 3 takes any remaining post offices and tries to use "fuzzy matching" to look for inexact matches across post offices Names and GNIS Names. I defined a function that used the [fuzzyjoin package in R](https://cran.r-project.org/web/packages/fuzzyjoin/) and selected the Levenshtein distance method within this package. [Levenshtein distance](https://en.wikipedia.org/wiki/Levenshtein_distance) calculates "the minimum number of single-character edits (insertions, deletions or substitutions) required to change one word into the other." I then used this to generate a similarity score from 0-1 representing the relative "string similarity" between the two names - essentially, how close is one string to the other based on the number of changes as a percentage of its total characters. A score of 1 would represent a full match requiring zero changes, while a string distance of 0.5 would require you to make changes equal to half the number of its total characters. 

For instance, one post office in Helbock dataset in Leavenworth County, Kansas, is named `STRINGER`. There was no exact match for this in the GNIS dataset, but the fuzzyjoin package found a fuzzy match with the GNIS Populated Place in Leavenworth County, Kansas, named `STRANGER`. The Levenshtein distance between `STRINGER` and `STRANGER` is `1 single-character edit` (changing `I` to `A`). To generate a similarity score, I subtracted `1 character edit` from the total string length of `8 total characters` in `STRINGER`, then divided by the total string length to arrive at a score of `0.875`.

I used a **threshold of 0.75** for this string distance score, meaning that the program would disregard any matches that fell below that score. I also put in a trigger that does not try to fuzzy match any names that are 4 characters or less, which would run a higher risk of false positives. Note: this phase is by far the most computationally greedy phase and takes many hours to run.

On March 15, 2021, Phase 3 found **6,512 matches**, or **3.92%** of the total post offices in Helbock's dataset.

### GNIS Geocoding Results

Combined, these three phases found **112,521 matches**, or **67.72%** of the total post offices in Helbock's dataset. This left **53,619** post offices that were not successfully geocoded through the GNIS database, or **32.28%** of the total post offices in Helbock's dataset. The final data for all post offices, both successfully and unsuccessfully geolocated, was written to: `us-post-offices.csv`.

Read the [US Post Offices Data Biography](https://cblevins.github.io/us-post-offices/data-biography) for a discussion of the results and things to keep in mind when using this dataset.

## Data Processing Steps: Assigning Semi-Random Coordinates

I also created an alternative dataset: `us-post-offices-random-coords.csv`. In this dataset, I assigned semi-random location coordinates to the post office records that were *not* successfully geocoded through the GNIS database. My starting point for this process was that Richard Helbock had collected information about each post office's county and state. This information provides a geographical boundary within which we know the post office was located (even if we don't know precisely where). The process for assigning random coordinates to post offices was completed in two steps.

In Step 1, I used the geospatial software QGIS to import a shapefile of US county boundaries for the year 2000 (from the Newberry Library's Atlas of Historical County Boundaries). The reason for selecting this year was that Helbock did not attempt to record historical counties for each post office, but rather recorded the county in which they were located when he was making his dataset. In this case, most of his work was published between 1998-2007, so I decided to use the year 2000 for county boundaries. I then used QGIS's `Random Points Inside Polygons` tool to generate 150 points that were randomly distributed inside every county in the United States. I exported these as `random-coordinates-150-per-county.csv`.

Step 2 was completed through `assign-random-coordinates.R`. The basic process involved importing `us-post-offices.csv` and `random-coordinates-150-per-county.csv`, and then joining post office records that had not been geocoded through the GNIS matching to random points from the corresponding county that had been generated in QGIS (using the unique state and county combination as a key to join them).

### Credits

- **Richard W. Helbock** (1938-2011) conducted the archival research to compile information about historical post offices. 
- [**Cameron Blevins**](https://cameronblevins.org) processed Helbock's data into a spatial-historical dataset and made it available online.

If you use the code in this repository, please cite: `Cameron Blevins, US Post Offices (2021), https://github.com/cblevins/us-post-offices.`

If you use the resulting dataset, please cite the Harvard Dataverse record:

<script src="https://dataverse.harvard.edu/resources/js/widgets.js?persistentId=doi:10.7910/DVN/NUKCNA&amp;dvUrl=https://dataverse.harvard.edu&amp;widget=citation&amp;heightPx=150"></script>

For more information, contact [Cameron Blevins](mailto:cameron.blevins@ucdenver.edu).