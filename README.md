- <a href="#overview" id="toc-overview">1 Overview</a>
  - <a href="#import-file-geodatabase-into-postresql"
    id="toc-import-file-geodatabase-into-postresql">1.1 Import file
    geodatabase into PostreSQL</a>
- <a href="#references" id="toc-references">2 References</a>

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

## 1.1 Import file geodatabase into PostreSQL

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

**In the Command Prompt Shell**

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

**Close the command prompt shell and open the OSGeo4W Shell**  
*The shell will probably open in the C: drive. If that is not where your
Postgres database is located, switch to the drive where it is located
(for example, the D: drive)*  
\> d:

**Load the geodatabase into the st_sim_demo database**  
\> ogr2ogr -f “PostgreSQL” PG:“host=localhost port=5432
dbname=st_sim_demo user=postgres”
D:\_program-sim-risk-assessment-demo\0_data\_dep_v2.gdb -overwrite
-progress –config PG_USE_COPY YES

*Note: there will probably be a few error messages because of geometry
type mismatches (Multisurface instead of Multipolygon). This seems like
an inevitable consequence of converting the .gdb format into a simple
features object in Postgres, and for this database there are only a few
polygons lost.*

# 2 References

<div id="refs">

</div>

<!--chapter:end:index.Rmd-->
