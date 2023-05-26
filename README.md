- <a href="#overview" id="toc-overview">1 Overview</a>
- <a href="#importing-a-geodatabase-into-postgresql"
  id="toc-importing-a-geodatabase-into-postgresql">2 Importing a
  geodatabase into PostgreSQL</a>
  - <a href="#in-the-command-prompt-shell"
    id="toc-in-the-command-prompt-shell">2.1 In the Command Prompt Shell</a>
  - <a href="#close-the-command-prompt-shell-and-open-the-osgeo4w-shell"
    id="toc-close-the-command-prompt-shell-and-open-the-osgeo4w-shell">2.2
    Close the command prompt shell and open the OSGeo4W Shell</a>
- <a href="#data-processing" id="toc-data-processing">3 Data
  processing</a>
- <a href="#rasterize-subregions" id="toc-rasterize-subregions">4
  Rasterize subregions</a>
- <a href="#rasterize-landcover" id="toc-rasterize-landcover">5 Rasterize
  landcover</a>
- <a href="#references" id="toc-references">6 References</a>

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

# 4 Rasterize subregions

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


ggplot() + geom_sf(data = nrsa, aes(fill = NSRNAME)) +
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

# 5 Rasterize landcover

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
box <- st_bbox(fmu_l3)

l3_rast <- terra::crop(rast(xmin = box$xmin, xmax = box$xmax, ymin = box$ymin, ymax = box$ymax, crs = crs(fmu), resolution = 100, vals = 1), vect(fmu_l3), mask = TRUE)

dep_l3_rast <- terra::crop(terra::rasterize(x = vect(dep_l3), y = l3_rast, field = "ep_code"), vect(fmu_l3), mask = TRUE)

# Check to make sure it passes the eye test
plot(dep_l3_rast)

# Write the raster to file
terra::writeRaster(dep_l3_rast, "0_data/processed/rasters/dep_l3.tif")
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

# 6 References

<div id="refs">

</div>

<!--chapter:end:index.Rmd-->
