- [1 Overview](#overview)
- [2 Importing a geodatabase into
  PostgreSQL](#importing-a-geodatabase-into-postgresql)
  - [2.1 In the Command Prompt Shell](#in-the-command-prompt-shell)
  - [2.2 Close the command prompt shell and open the OSGeo4W
    Shell](#close-the-command-prompt-shell-and-open-the-osgeo4w-shell)
- [3 Data processing](#data-processing)
  - [3.1 Rasterize subregions](#rasterize-subregions)
  - [3.2 Rasterize landcover](#rasterize-landcover)
  - [3.3 Historic fire distributions](#historic-fire-distributions)
  - [3.4 Rasterize seismic lines](#rasterize-seismic-lines)
- [4 References](#references)

# 1 Overview

One of the most pressing problems in ecology and conservation is
understanding effects of anthropogenic disturbance and climate change on
wildlife populations and biodiversity \[@Venier2021\]. Complicating this
understanding is the fact that these cumulative effects are occurring
within the context of global climate change, meaning that models based
on historical responses to disturbance might no longer be valid
\[@Jackson2021\], leading to unanticipated outcomes from management
actions. Anticipating and responding to potential ecosystem changes from
the interactions of anthropogenic disturbance with climate change, and
risks to biodiversity from those changes, requires a probabilistic
ecological forecasting approach within a risk assessment framework to
quantify the risks and uncertainties, and ultimately inform the
decision-making process \[@milner-gulland2010a\].

**Project description** The Objective of this project is to develop a
simple state-and-transition simulation model and use it to assess the
forecast population responses by a species of interest.

# 2 Importing a geodatabase into PostgreSQL

Very often, landscape simulation models require the storage and
processing of very large geospatial databases (10s to 100s of GB) that
are downloaded as an ArcGIS geodatabase.

Because such large databases can be very difficult and time consuming to
process in R, I typically store them in a PostgreSQL database with the
PostGIS extension, and process them remotely by connecting to the
database through R.

The following is command line instructions for setting up a new PostGIS
database and importing geospatial data stored as a file geodatabase.

For information and instructions on downloading PostgreSQL and setting
up the PostGIS extension, see, for example, [this
tutorial](https://postgis.net/workshops/postgis-intro/installation.html).

For this demonstration, we will be using the Alberta Derived Ecosite
Phase database as our baseline natural land-cover database, which can be
downloaded
[here](https://open.alberta.ca/opendata/gda-ae37f83c-c994-47a9-b2f0-39ba1da0e64c).

Unzip the files to the location of your choice.

**And by all means, if you are more comfortable working in ArcGIS or
Python, do it that way.**

## 2.1 In the Command Prompt Shell

To open the command prompt in Windows, type ‘cmd’ into the search bar at
the bottom left of the screen, then hit Enter.

Next, type in:  
\> cmd.exe /c chcp 1252  
\> cd C:4w64

**Create the database**  
\> createdb -U postgres st_sim_demo

**Connect to the database**  
\> psql -d st_sim_demo -U postgres

**Add the PostGIS extension**  
\> CREATE EXTENSION postgis;

## 2.2 Close the command prompt shell and open the OSGeo4W Shell

*The shell will probably open in the C: drive. If that is not where your
Postgres database is located, switch to the drive where it is located
(for example, the D: drive)*  
\> d:

**Load the geodatabase into the st_sim_demo database**  
\> ogr2ogr -f “PostgreSQL” PG:“host=localhost port=5432
dbname=st_sim_demo user=postgres” path_to_geodatabase.gdb -overwrite
-progress –config PG_USE_COPY YES

*Note: there will probably be a few error messages because of geometry
type mismatches (Multisurface instead of Multipolygon). This seems like
an inevitable consequence of converting the .gdb format into a simple
features object in Postgres, and for this database there are only a few
polygons lost.*

# 3 Data processing

## 3.1 Rasterize subregions

An ST-Sim model requires a raster that delineates the study area. In
many ST-Sim analyses, there will be \>1 sub-region within the main study
area, with some parameters and transition probabilities differing
between sub-regions. In this demo, I am limiting the analysis to a
single Forest Management Unit (FMU) in Alberta, so we are not too
worried about sub-regions, but we will go through the process anyway.

We delineate sub-regions using the **Natural Regions and Sub-regions
database** from the Government of Alberta
\[@naturalregionscommittee2006\]. This database is made available here
because it if very difficult to find the downloadable shapefile.

**The Alberta Forest Management Units (FMU) database**, from which we
will use FMU L3 can be downloaded from Data Basin
[here](https://databasin.org/datasets/606eb8aad3ec4d4fb1406d0159d15280/).
Because I will be saving these in the Postgres database, I will convert
all the field names to lower case letters. For some reason, Postgres has
a hard time working with upper case letters in the field names.

``` r
nrsa <- st_read("0_data/raw/shapefiles/Natural_Regions_Subregions_of_Alberta/Natural_Regions_Subregions_of_Alberta.shp")
colnames(nrsa) <- tolower(colnames(nrsa))

fmu <- st_transform(st_read("0_data/raw/alberta_fmu/data/data/BF_FMU_POLYGON_10TM/BF_FMU_POLYGON_10TM.shp"), crs = 3400)
colnames(fmu) <- tolower(colnames(fmu))

# Filter the L3 fmu 
fmu_l3 <- fmu %>% filter(fmu_name == "L3")


ggplot() + geom_sf(data = nrsa, aes(fill = nsrname)) +
  geom_sf(data = fmu_l3, fill = NA, linewidth = 1)



# Export the fmu layers to Postgres  

# Enter the username and password without putting it into your code
# Note: Once you enter these, they will be visible in your R environment, so I remove them after connecting to the database
username <- rstudioapi::askForPassword("Database username")
password <- rstudioapi::askForPassword("Database password")

pg = dbDriver("PostgreSQL")
# Local Postgres.app database; no password by default
# Of course, you fill in your own database information here.
con = dbConnect(pg, user = username, password = password,
                host = "localhost", port = 5432, dbname = "st_sim_demo")
rm(list = c("username", "password"))

st_write(fmu, con, layer = "alberta_fmu")
st_write(fmu_l3, con, layer = "fmu_l3") 
st_write(nrsa, con, layer = "alberta_natural_subregions") 
st_write(fmu_l3, "0_data/processed/shapefiles/fmu_l3.shp") 
```

We will create the rasters using the ‘rasterize’ command from the
‘terra’ package. The first step is to create a template raster from the
L3 FMU layer using a 100m cell resolution. Then I will use the template
to rasterize the natural sub-regions polygons.

``` r
# Create the template raster
box <- st_bbox(fmu_l3)

l3_rast <- terra::crop(rast(xmin = box$xmin, xmax = box$xmax, ymin = box$ymin, ymax = box$ymax, crs = crs(fmu), resolution = 100, vals = 1), vect(fmu_l3), mask = TRUE)
plot(l3_rast)

writeRaster(l3_rast, "0_data/processed/rasters/l3_rast.tif")
```

``` r
# Create the template raster
box <- st_bbox(nrsa)

ab_rast <- terra::crop(rast(xmin = box$xmin, xmax = box$xmax, ymin = box$ymin, ymax = box$ymax, crs = crs(fmu), resolution = 100, vals = 1), vect(nrsa), mask = TRUE)

nrsa_rast <- terra::rasterize(nrsa, ab_rast, field = "nsrname")
plot(nrsa_rast)
writeRaster(nrsa_rast, "0_data/processed/rasters/ab_natural_subregions.tif")

ab_nr_rast <- terra::rasterize(nrsa, ab_rast, field = "nrname")
plot(ab_nr_rast)
writeRaster(ab_nr_rast, "0_data/processed/rasters/ab_natural_regions.tif") 

l3_nrsa_rast <- terra::crop(nrsa_rast, vect(fmu_l3), mask = TRUE)
plot(l3_nrsa_rast)

freq(l3_nrsa_rast)
```

Although a substantial portion of the study are is in the Lower Boreal
Highlands, at this point we will assume constant parameters across the
area (i.e., no sub-regions in the model).

## 3.2 Rasterize landcover

I am classifying landcover using the Alberta Derived Ecosite Phase
database \[governmentofalberta2020\], which classifies landcover
polygons according to geography, soil, moisture regime, and dominant
vegetation. These instructions are for interacting with the data stored
in a PostgreSQL database, but if you have it stored in another place,
just modify your code to interact with it that way.

Connect to the PostgreSQL database

``` r
# Enter the username and password without putting it into your code
# Note: Once you enter these, they will be visible in your R environment, so I remove them after connecting to the database
username <- rstudioapi::askForPassword("Database username")
password <- rstudioapi::askForPassword("Database password")

pg = dbDriver("PostgreSQL")
# Local Postgres.app database; no password by default
# Of course, you fill in your own database information here.
con = dbConnect(pg, user = username, password = password,
                host = "localhost", port = 5432, dbname = "st_sim_demo")
rm(list = c("username", "password"))
```

Now, to the reason we are using Postgres for some of our data
processing. The amount of memory needed to load the dep dataset into R,
and then clip it to the L3 FMU layer, would crash the program on most
computers. Sending the job to Postgres as a query, though, works just
fine.

``` r
dep_l3 <- st_read(con, query = "SELECT * 
                  FROM dep 
                  WHERE ST_Intersects(dep.shape, (
                  SELECT geometry 
                  FROM fmu_l3
                  WHERE fmu_name = 'L3'));")


dep_l3$raster_code <- as.numeric(as.factor(dep_l3$ep_code)) 

dep_l3 <- st_write(dep_l3, con, "dep_l3")
```

The next step is to rasterize the dep data so that it can be input into
the st-sim model. I will start by creating a template raster from the L3
FMU layer using a 100m cell resolution. The I will use the template to
rasterize the dep polygons.

``` r
# Create the template raster 

fmu_l3 <- st_read("0_data/processed/shapefiles/fmu_l3.shp")

box <- st_bbox(fmu_l3)

l3_rast <- terra::crop(rast(xmin = box$xmin, xmax = box$xmax, ymin = box$ymin, ymax = box$ymax, crs = crs(fmu), resolution = 100, vals = 1), vect(fmu_l3), mask = TRUE)

dep_l3_rast <- terra::crop(terra::rasterize(x = vect(dep_l3), y = l3_rast, field = "ep_code"), vect(fmu_l3), mask = TRUE)

# Check to make sure it passes the eye test
plot(dep_l3_rast)

# Write the raster to file
terra::writeRaster(dep_l3_rast, "0_data/processed/rasters/dep_l3.tif", overwrite = TRUE)
```

Finally, I am using a simplified version of the ecosystem classes for
this demo using the 9 classes derived from @Hart2019, so we need a look
up file to reclassify the raster with.

``` r
# Read in the dep lookup file
dep_lookup <- read.csv("0_data/st-sim/dep_lookup.csv")

# Create the reclassification table 
reclass <- data.frame(id = as.numeric(as.factor(dep_lookup$ep_code)), v = as.numeric(as.factor(dep_lookup$ep_code_hart)))

# Create the new raster 
dep_l3_hart <- dep_l3_rast

# Re-set the ep codes to numeric values (the 'subst' command requires numeric values)
values(dep_l3_hart) <- as.numeric(as.factor(values(dep_l3_hart))) - 1 

# Set the 0 and 41 values to NA
dep_l3_hart <- subst(dep_l3_hart, c(0, 41), NA) 

dep_l3_hart <- subst(x = dep_l3_hart, from = reclass$id, to = reclass$v) 
plot(dep_l3_hart)  # Give it the eye test 


writeRaster(dep_l3_hart, "0_data/processed/rasters/dep_l3_hart.tif", overwrite = TRUE)
```

## 3.3 Historic fire distributions

I am simulating temporal variability in overall burn probabilities, and
typical fire sizes, by deriving them from Alberta’s historic fire
database. This is a shapefile that can be downloaded
![here](https://www.alberta.ca/wildfire-maps-and-data.aspx), as the
‘Historic Wildfire Perimeter Data: 1931 to 1922’.

To ensure the data used in the simulations reflected the modern fire
regime in the region, I limited to data to only those fires occurring
since 2006 within the boreal ecological region of Alberta.

``` r
# Load the fire database. 
hist_fire <- st_read("0_data/raw/HistoricalWildfirePerimeters/WildfirePerimeters1931to2022.shp")

# Filter to only fires occurring since 2006. 
fire_2006 <- hist_fire %>% filter(YEAR >= 2006)

# Load the natural regions database and clip the fire data to the Boreal ecological region. 
nr <- st_read("0_data/raw/Natural_Regions_Subregions_of_Alberta/Natural_Regions_Subregions_of_Alberta.shp")

nr_boreal <- nr %>% filter(NRNAME == "Boreal")

fire_boreal <- fire_2006[nr_boreal, ]

st_write(fire_boreal, "0_data/processed/shapefiles/fire_boreal_2006-2022.shp")
```

The next step is to characterize temporal variability in amount of area
burned as the total area burned in a year divided by the mean area
burned among all years to create the distribution of fire multipliers
$y$, where $y=1$ is the mean and $0< y<\infty$. In the ST-Sim model,
this allows the total amount of area burned to vary stochastically
around the mean by randomly drawing a multiplier from the distribution
at each time step, and multiplying the baseline burn probabilities by
that number for that time step.

``` r
yr_var <- st_drop_geometry(fire_boreal %>% group_by(YEAR) %>% summarise(total_area = sum(HECTARES_U)))

yr_var$area_mean <- yr_var$total_area/mean(yr_var$total_area) 
write.csv(yr_var, file = "0_data/st-sim/hist-fire-variability.csv")
```

Finally, create a distribution of maximum fire sizes for the simulator
to draw from by binning them and counting the number of fires in each
bin. Because the distribution of sizes is so strongly right-skewed, use
the log of the area burned for binning so that the bins can capture the
full range of fire sizes rather then lumping them all into the smallest
size category. The code will pre-emptively format the table for loading
into SyncroSim.

``` r
# Some of the fires have area = 0, so remove those first. 
fire <- fire_boreal %>% filter(HECTARES_U > 0) 

# This is a strongly right-skewed distribution, so to include the full range of fire, including the largest, bin them using the log of the area rather than the area
fire_size_bins <- st_drop_geometry(fire) %>% select(FIRENUMBER, HECTARES_U) %>% 
  mutate(area_bin = cut(log(HECTARES_U), breaks = 10))
fire_size_bins$bin_num <- as.numeric(fire_size_bins$area_bin)

fire_size_bins <- st_drop_geometry(fire) %>% select(FIRENUMBER, HECTARES_U) %>% 
  mutate(area_bin = cut(log(HECTARES_U), breaks = 10))
fire_size_bins$bin_num <- as.numeric(fire_size_bins$area_bin)

area_bins <- data.frame(TransitionGroupID = "Fire [Type]", fire_size_bins %>% group_by(bin_num) %>% summarise(MaximumArea =  max(HECTARES_U), RelativeAmount = length(HECTARES_U)) %>% select(-bin_num))
print(area_bins)


write.csv(area_bins, "0_data/st-sim/fire_area_bins.csv", row.names = FALSE)
```

## 3.4 Rasterize seismic lines

An important part of habitat change brought about by energy sector
development is the creation of seismic lines. Thus, tracking seismic
line recovery is important for assessing effects on wildlife habitat.
Also, disturbances such as fire and harvest can effectively ‘erase’
these lines by re-starting the succession process both on the lines and
in the adjacent ecosystem.

The shapefile of current seismic lines can be obtained from ![this
link](https://abmi.ca/home/data-analytics/da-top/da-product-overview/Human-Footprint-Products/HF-inventory.html).
I used the ‘Enhanced for Oil Sands Monitoring Region (2019)’ version.
This comes as a geodaatabase. Unfortuneately, R and PostGIS don’t tend
to work well with .gdb files, so for me it was necessary to use QGIS to
open the ‘o20_SeismicLines_HFIeOSA2019’ layer from the geodatabase, and
then save it as a shapefile to my project library as
“0_data/raw/shapefiles/hfieosa_2019.shp”.

``` r
# Load the shapefile 
seismic_osr <- st_read("0_data/raw/shapefiles/hfieosa_2019.shp")

# Validate the geometries
seismic_osr$geometry <- st_make_valid(seismic_osr$geometry)

# Get the template layer layer
nrsa <- rast("0_data/processed/rasters/ab_natural_subregions.tif")
osr <- st_read("0_data/raw/shapefiles/osr_epsg3400.shp")

seismic_rast <- rasterize(vect(seismic_osr), nrsa, field = "FEATURE_TY", touches = TRUE) 

seismic_rast <- crop(seismic_rast, vect(osr), mask = TRUE)
plot(seismic_rast)

writeRaster(seismic_rast, "0_data/processed/rasters/seismic_osr_2019.tif")
```

Finally, crop the seismic layer to the L3 FMU.

``` r
# Load the L3 shapefile 
fmu_l3 <- st_read("0_data/processed/shapefiles/fmu_l3.shp")

seismic_l3 <- crop(seismic_rast, vect(fmu_l3), mask = TRUE)
plot(seismic_l3)

writeRaster(seismic_l3, "0_data/processed/rasters/seismic_l3.tif")
```

# 4 References

<div id="refs">

</div>

<!--chapter:end:index.Rmd-->
