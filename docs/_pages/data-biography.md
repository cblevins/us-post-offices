---
layout: page
title: US Post Offices Data Biography
permalink: /data-biography/
--- 

## Cameron Blevins (March 30, 2021)

### Introduction

`US Post Offices` is a spatial-historical dataset containing records for 166,140 post offices that operated in the United States between 1639 and 2000. The dataset provides a year-by-year snapshot of the national postal system and its geography over multiple centuries, making it one of the most fine-grained spatial datasets ever assembled about US history. Postal historian and philatelist Richard Helbock collected the historical information about these post offices and [Cameron Blevins](https://cameronblevins.org) processed the data to geocode the records. The following presents a [data biography](https://weallcount.com/2019/01/21/an-introduction-to-the-data-biography/) for `US Post Offices` detailing how it was created and and how it should be used.

### Origins

Richard W. Helbock (1938-2011) collected the historical data for `US Post Offices`. A geography professor, Helbock was a leader in the philatelic community, including founding the journal *La Posta: A Journal of American Postal History* in 1969. Helbock spent decades researching the history of the US postal system. This culminated between 1998-2007, during which he published the eight-volume series [*United States Post Offices*](https://www.goodreads.com/series/127505-united-states-post-offices), in his words: "the first attempt to publish a complete listing of all the United States post offices which have ever operated in the nation." With each volume covering a different region of the United States, these reference books contained historical information about thousands of individual post offices, including their name, county, state, and years of operation. The primary motivation behind Helbock's original dataset was for philately, or stamp collecting. His eight volumes were designed to meet the needs of stamp collectors who could use them to help determine the scarcity (and therefore approximate value) of a postmark from any particular post office. 

In addition, Helbock produced a Microsoft Access Database of his research to accompany the printed volumes, sold on a CD-ROM. This was one of the key decisions that would eventually allow for his work to become `US Post Offices`. The second decision was made by his wife, Catherine Clark. Helbock tragically passed away in 2011. Clark, who had been working with Helbock to publish the *La Posta* journal, took over many aspects of her late husband's work - including continuing to make Helbock's dataset available for purchase online. `US Post Offices` would never have been created without her contributions.

In 2013, Cameron Blevins was a PhD student at Stanford University doing research for his dissertation. After spending months transcribing post office records by hand, he discovered Helbock's dataset online and purchased the CD-ROM from Catherine Clark. He began working on a geocoding process to try and turn Helbock's historical data into spatial data, an early version of which he used to complete his dissertation. He continued to refine the geocoding process over the years, eventually arriving at the steps described in more detail in [Processing the Richard Helbock Dataset](helbock-data-processing.html). The primary motivation for Blevins to create `US Post Offices` was for academic research. In particular, he developed the dataset in order to analyze the history of the western postal system in the late 1800s. He released the dataset in 2021 to coincide with the publication of his book, [*Paper Trails: The US Post and the Making of the American West*](https://global.oup.com/academic/product/paper-trails-9780190053673).

### What's in the dataset?

`US Post Offices` contains 166,140 records of post offices that operated in the United States. Each individual record represents information about a single post office, including its name, location, and approximate dates of operation. It includes post offices that operated within fifty US states, but does not include post offices that operated in territories that did not become states (ex. Puerto Rico). The earliest post office in the dataset opened in 1639 and the most recent in 2000.

<p style="text-align: center;"><img src="{{site.baseurl}}/images/usa-all-records.png" width="700" align="center"><i>Records from `US Post Offices` in the contiguous United States. Darker points represent exact locations and lighter points are randomly located within their surrounding county.</i></p>

`US Post Offices` includes two data files. The first file, `us-post-offices.csv`, contains geographical coordinates only for those post offices that were successfully geocoded using the process described below. The second file, `us-post-offices-random-coords.csv`, is an alternative dataset that contains geographical coordinates that were semi-randomly assigned to post offices that were not successfully geocoded. You can find explanations of the different fields in these two files in `us-post-offices-data-dictionary.csv`. Please read more about the differences between these data files before deciding which one to use.

### How was the dataset made?

The creation of `US Post Offices` can be broken into two stages: archival research compiled by Richard Helbock and data processing by Cameron Blevins.

#### Stage 1: Archival Research

Richard Helbock created a dataset of post offices over several decades of archival research from the 1970s to the early 2000s. The main source for this information was the US Post Office Department's [*Records of Appointments of Postmasters*](https://www.archives.gov/research/post-offices/postmasters-1832-1971.html), in which the Department recorded information about postmaster appointments at the nation's post offices.

<p style="text-align: center;"><img src="{{site.baseurl}}/images/records-of-appointments-of-postmasters-example-washington.png" width="600" align="center">
<i>Microfilmed page from Records of Appointments of Postmasters (Roll 136, Cowlitz County, Washington State)</i></p>

Helbock also consulted many other kinds of sources, including lists and collections of post offices created by other philatelists and postal historians. The major challenge he faced in compiling his dataset was to decide what, exactly, constituted a single record for an individual "independent post office." As he noted, what should he do if a post office changed names from "Hillsborough" to "Hillsboro"? Should he leave this as a single post office with the new name, or create two separate records? What if that post office changed locations, or closed for a few years and then re-opened? Helbock helpfully provided documentation about the decisions he made when collecting and recording information in the introductions to his eight volumes. Many of these decisions revolved around the nature of historical post offices prior to the early 20th century, when they were much more fluid entities than they are today. 

- **General approach:** 
  - Helbock: "The overall rule of thumb applied to the listing of post office names was “Keep it Simple.” In other words, if the choice came down to making a double listing or a single listing for a particular post office with a minor name change due to spelling differences, the single listing was chosen. There are, however, many exceptions to this rule."
- **Closings and Re-Openings:** 
  - **Caveat**: 21,040 post offices (12.7% of the total) were were NOT in continuous operation between their established and discontinued years. For any given year, there is a small chance that they were actually temporarily closed.
  - Unlike today's post offices, it was common for pre-20th century post offices to temporarily shut down their operations before re-opening months or even years later. This process could happen multiple times for the same post office. Rather than making a new post office record, Helbock decided to use a 10-year cutoff: if the post office was closed for *less than 10 years* before re-opening, he kept it under the same record. If it remained closed for *10 years or more* before re-opening, he treated it as two separate post offices and created a second record for the "new" post office.
  - Helbock did not record detailed information about all of these closings and re-openings. Instead, he summarized this in a column in his dataset that was a simple binary of whether or not the post office was in continuous operation between its established and discontinued date. 
- **Location changes:** 
  - **Caveat**: Historical post offices switched locations with some frequency. For example, if a new postmaster was appointed they might move the post office from the town's hotel to their own general store a mile up the road. These kinds of changes are NOT captured in the dataset.
  - Helbock: "In the case of post offices which changed locations with the appointment of new postmasters, it was decided that a single listing would be sufficient so long as the office remained in continuous operation, or experienced a break in service of less than 10 years."
- **Name changes:**
  - **Caveat**: Historical post offices could change names, which are difficult to capture. For the purposes of the dataset, this means that not every "established" year for a post office represents the opening of a brand-new office, and not every "discontinued" year represents a post office closure.
  - Helbock: "A major change of name is treated as a discontinuance, as is conversion of an independent office to the status of station or branch." 
  - For instance, if a post office changed from "Albany" to "Zeb's Store," he made a second record in his dataset, even if it may have been the same physical post office. This means that for a small percentage of post office records, the year they were "discontinued" in the dataset may have represented a change of name rather than a closure. Similarly, an "established" year may have represented a new name for an ongoing operation, rather than a brand-new post office.
  - Helbock: "Post offices which experienced a name change from a two word to a one word format are typically listed only under the form which was in use for the longest period of time." For instance, Helbock did not create a second record if a post office changed from Browns Ville to Brownsville. 
- **States and Counties:** 
  - Helbock: "Counties given for post offices in this list are those in which the office, or its site, are currently located. No attempt has been made to list county assignments for early day offices which do not coincide with current county boundaries." 
  - Essentially, Helbock assigned post offices counties at the time in which he was collecting the data (ie. the late 1900s) rather than the county at the time in which the post office was operating. These are often the same county, but the boundaries of a surrounding county may have shifted so that its modern location falls within a different county. 
  - Specific states have some county quirks in Helbock's data collection: a) Hawai'i post offices are identified by island instead of county, and b) Alaska post offices do not include a county.
- **Stamp Scarcity Index**
  - Helbock included a Stamp Scarcity Index score from 0-9 in his dataset to help stamp collectors: "Inclusion of a Scarcity Index (S/I) value for each post office listed herein is, far and away, the most arbitrary piece of information in the listing...The S/I value assigned to each post office is intended to reflect the relative scarcity of the most commonly occurring type of postmark for each office."
- **Miscellaneous:**
  - Helbock: "Post offices believed to have never been in actual operation, i.e., the so-called 'paper offices' have been omitted from the listing in cases where they have been identified as such. Many post offices listed in the “Records of Appointments of Postmasters” are noted to have been “rescinded”, rather than discontinued."
  - Helbock: "It does not include contract or classified branches, stations, or community post offices (CPO), even though some of these postal units have postmarked mail using their own name independently of their parent post office." 

#### Stage 2: Data Processing

***Main Dataset: Geocoding using the GNIS Database***

Richard Helbock's dataset contained a wealth of historical information. To turn it into a spatial dataset, it needed to go through a process of geocoding, or assigning geographical coordinates to each individual post office. Cameron Blevins refined this geocoding process between 2014-2021. He useda historical gazetteer approach baseds on the [Geographic Names Information System (GNIS) Domestic Names](https://www.usgs.gov/core-science-systems/ngp/board-on-geographic-names/domestic-names) database collected by the U.S. Board on Geographic Names, under the U.S. Geological Survey. Blevins wrote a series of scripts in R that attempted to take the name, county, and state of a post office and look for a corresponding match in the GNIS dataset to find its geographical coordinates. A longer and more detailed description of this process can be found in [Processing the Richard Helbock Dataset]({{site.baseurl}}/data-processing). Blevins's geocoding process found geographical coordinates for **112,521** out of 166,140 post offices (**67.73%** of all the records). These coordinates can be found `us-post-offices.csv`. 

The geocoding process has direct implications for how to use `US Post Offices` as a spatial dataset. First, and most importantly, if you are using `us-post-offices.csv` to make a map of post offices it will NOT capture every single post office in operation. Many data points will be missing from the map. This is an obvious point, but it is arguably the most important one to keep in mind when working with this data.

Second, there is wide geographical variation in how successful the geocoding process was for different parts of the country. Whether or not a post office could be geocoded was often dependent on how comprehensive the GNIS records were for its state. at the extremes, the geocoding process successfully found coordinates for **98.35% of Oregon post offices** vs. just **49.32% of North Carolina post offices.** 

<p style="text-align: center;"><img src="{{site.baseurl}}/images/state-analytics-barchart.png" align="center"><i>Percentage of a state's total post offices successfully geolocated using the GNIS database</i></p>

Any maps made with `us-post-offices.csv` will display a larger share of the actual post offices in operation in areas like New England, the Midwest, and many parts of the the Far West (especially the Pacific Slope). Conversely, areas of the South and a few pockets such as Colorado, Wyoming, and Oklahoma will have a much lower proportion of their post offices displayed on a map.

<p style="text-align: center;"><img src="{{site.baseurl}}/images/state-analytics-map.png" width="600" align="center"><i>Percentage of a state's total post offices successfully geolocated using the GNIS database</i></p>

Third, the geocoding success rate was not evenly distributed across the dataset. Post offices that were in operation for longer periods of time were more likely to find a match in the GNIS dataset than post offices that only existed for a short period of time. Post offices that were successfully matched in the GNIS database were in operation for an average (median) of **38 years**. That number was just **5 years**, on average, for post offices that did *not* have a match in the GNIS database. This makes sense. GNIS features were created by consulting historical records such as maps, and post offices that only existed for a short period of time appear in far fewer historical records. However, it also also means that any visualizations relying on geocoded coordinates in this dataset are going to be skewed *towards* more stable, long-lasting post offices and *away* from post offices that operated for a shorter period of time. 

Fourth, even those post offices that *were* successfully geocoded using the GNIS database may not have the right geographical coordinates. There are a scattering of false positives - ie. a post office that was matched to the wrong GNIS feature. As detailed in [Processing the Richard Helbock Dataset](helbock-data-processing.html), Blevins minimized false positives through a variety of steps, but there are undoubtedly a small number of post offices whose locations are incorrect. The error for these should be constrained to within the surrounding county, however.

Fifth, a post office's geographical coordinates can be imprecise. The records in this dataset do not all have pinpoint accuracy when it comes to their location on the earth's surface. These records should not, for instance, be used to distinguish the location of a post office *within* a community, town, or city (ie. whether it was located on Main Street or First Avenue).

***Alternative Dataset: Semi-Random Coordinates*** 

Is it better to have a map with some *missing* data or a map with some *inaccurate* data? This question led Cameron Blevins to create an **alternative dataset** in `US Post Offices` for visualization and illustrative purposes: `us-post-offices-random-coords.csv`. The creation of this dataset is described in more detail in [Processing the Richard Helbock Dataset](helbock-data-processing.html). 

The alternative dataset `us-post-offices-random-coords.csv` includes semi-random geographical coordinates assigned to post offices that had not been geocoded using the GNIS database. This was made possible by the fact that Richard Helbock recorded information about the state and county of a post office. Even if we don't know its exact location, we know the post office fell somewhere within a particular county's borders. Blevins used county boundary shapefiles to generate a set of randomly distributed points within the borders of every county in the United States and then randomly paired those coordinates with post offices located within that county that had *not* been matched to a GNIS record. Although the specific location of each post office is incorrect, the potential error is constrained to the surrounding county - ie. a post office in Florida is not going to be located in Vermont, and a post office outside Los Angeles is not going to be placed near San Francisco.

The basic idea behind this approach involves a tradeoff between accuracy and precision. A map using `us-post-offices.csv` shows *only* post offices that were successfully geocoded using the GNIS database, and has a relatively high degree of **precision** (each of the points on the map are probably located in the right spot) but lower overall **accuracy** (there might be hundreds or thousands of missing data points). Conversely, a map using `us-post-offices-random-coords.csv` shows *all* post offices from the dataset - including those with semi-random coordinates - and might be more **accurate** (there are no missing data points) but has a much lower degree of **precision** (some data points aren't in the right location within a county). 

To see this tradeoff between `us-post-offices.csv` vs. `us-post-offices-random-coords.csv`, let's take a look at Colorado in the year 1880. Colorado had one of the lowest percentage of post offices that were successfully geocoded using the GNIS database. This means that a map of its post offices will be missing a lot of data, giving an incomplete picture of the state's postal coverage. One could argue that adding in the missing post offices using `us-post-offices-random-coords.csv` creates a more "accurate" overall picture of the extent of Colorado's postal coverage in 1880:

<p style="text-align: center;"><img src="{{site.baseurl}}/images/randomcoords-example-co-1880.gif" width="500" align="center"><i>The tradeoff between `us-post-offices.csv` vs. `us-post-offices-random-coords.csv`</i></p>
 
Each of the light blue points on the map does *not* represent the precise location of a post office and is likely "off" by many miles. To drive this home, we can re-run the process of matching post offices to randomly distributed coordinates within a county and then compare the results on a map. If we were to zoom out to a nation-wide map of the United States, it would be hard to pick up much of a difference. But zoomed in to a state level, the differences between two sets of semi-randomized points can be quite noticeable: 

<p style="text-align: center;"><img src="{{site.baseurl}}/images/randomcoords-compare-co-1880.gif" width="500" align="center"><i>Two sets of semi-randomized coordinates for post offices that were not successfully geocoded</i></p>

### How should I use this dataset?

Short answer: Carefully! :) Before using `US Post Offices`, review `us-post-offices-data-dictionary.csv` and read the following:

**Decide which data file to use.** 

- As outlined above, there is a tradeoff between `us-post-offices.csv` and `us-post-offices-random-coords.csv`. For mapping purposes, you need to weigh the benefits and downsides of using an incomplete spatial dataset vs. one with semi-randomized locations for some of its records. If you are mapping zoomed-in areas or trying to show the exact locations of a specific set of post offices, consider using `us-post-offices.csv` along with an explanation of its missing data points. If you are mapping larger areas or and more general spatial patterns of coverage and extent, the individual errors of specific post office locations aren't going to be as visible and you should consider using `us-post-offices-random-coords.csv` with an explanation of its semi-randomized coordinates.

**Exercise caution when doing any kind of precise quantitative analysis.** 

- The limitations of this dataset make it much more effective for illustrative and visualization purposes than for precise quantitative analysis along its geographical and temporal dimensions. For instance, we might want to ask a spatial question such as: how far away was the average post office from a railroad line? But given how many post offices have either missing or inexact locations, this kind of analysis is thorny at best. The same goes for the temporal information captured in the `Established`, `Discontinued`, and `Continuous` fields. Review these fields in the `us-post-offices-data-dictionary.csv` to make sure you understand what they do and do not represent.

**Post offices are NOT a direct or stable proxy for population.** 

1. A post office says nothing about the number of people living nearby: the New York City post office looks identical on postal maps to a small rural post office serving a fraction as many people. If you're looking for data about the historical populations of US towns and cities, you should look for a source such as the [Alperin-Sheriff/Wikipedia Population dataset](http://creatingdata.us/datasets/US-cities/).

2. It is tempting to see a post office as a spatial proxy for a surrounding community. And to some degree, this is true: the presence of a post office *does* indicate that a group of people was living nearby. But the inverse is not true: the **absence** of a post office does not necessarily mean that nobody lived nearby. In fact, through the late 1800s the absence of post offices often indicated the **presence** of Indigenous groups who either blocked settler expansion or who suffered from a lack of postal coverage on government reservations. 

<p style="text-align: center;"><img src="{{site.baseurl}}/images/pos-native-land.gif" width="700" align="center"><i>This map shows the relationship between Native land, government reservations, and postal expansion.</i></p>

3. The relationship between a post office and a surrounding population changed over time. A post office in 1850 was not the same as a post office in 1950. In particular, the rollout of Rural Free Delivery in the early 20th century caused a widescale consolidation in the network. This new service meant that rural residents went from fetching their mail at the local post office to having it delivered to their doorstep, which caused the closure of thousands of post offices. This did not indicate that people were moving away from those areas; it was simply that fewer post offices could now serve a larger surrounding area. 

<p style="text-align: center;"><img src="{{site.baseurl}}/images/usa-discontinued-1890-1930-2fps-800width.gif" width="700" align="center"><i>Rural Free Delivery (officially instituted in 1902) caused the closure of thousands of post offices.</i></p>