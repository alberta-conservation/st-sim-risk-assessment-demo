- <a href="#overview" id="toc-overview">1 Overview</a>
- <a href="#example-project" id="toc-example-project">2 Example
  Project</a>
  - <a href="#import-file-geodatabase-into-postgresql"
    id="toc-import-file-geodatabase-into-postgresql">2.1 Import file
    geodatabase into PostgreSQL</a>
  - <a href="#load-file-geodatabase-into-postresql"
    id="toc-load-file-geodatabase-into-postresql">2.2 Load file geodatabase
    into PostreSQL</a>
- <a
  href="#load-the-geodatabase-into-the-st_sim_demo-database.-note-this-takes-a-looooong-time"
  id="toc-load-the-geodatabase-into-the-st_sim_demo-database.-note-this-takes-a-looooong-time">3
  Load the geodatabase into the st_sim_demo database. Note: THIS TAKES A
  LOOOOONG TIME!</a>
- <a href="#references" id="toc-references">4 References</a>

# 1 Overview

# 2 Example Project

**Project description** The Objective of this project is to develop a
simple state-and-transition simulation model and use it to assess the
risk to a species of interest

## 2.1 Import file geodatabase into PostgreSQL

## 2.2 Load file geodatabase into PostreSQL

Very often, landscape simualtion models require the storage and
processing of very large geospatial databases (10s to 100s of GB) that
are downloaded as an ArcGIS geodatabase.

Because such large databases can be very difficult and time consuming to
process in R, I typically store them in a PostgreSQL database with the
PostGIS extension, and process them remotely by connecting to the
databse through R.

The following is command line instructions for setting up a new PostGIS
database and importing geospatial data stored as a file geodatabase.

For information and instructions on downloading PostgreSQL and setting
up the PostGIS extension, see, for example, [this
tutorial](https://postgis.net/workshops/postgis-intro/installation.html).

For this demonstration, we will be using the Alberta Derived Ecosite
Phase database as our baseline natural land-cover database, which can be
downloaded
[here](https://open.alberta.ca/opendata/gda-ae37f83c-c994-47a9-b2f0-39ba1da0e64c).

Unzip the file to the location of your choice.

**In the Command Prompt Shell** To open the command prompt in Windows,
type ‘cmd’ into the search bar at the bottom left of the screen, then
hit Enter.

Next, type in: cmd.exe /c chcp 1252

cd C:4w64

**Create the database** createdb -U postgres st_sim_demo

**Connect to the database** psql -d st_sim_demo -U postgres

**Add the PostGIS extension** CREATE EXTENSION postgis;

**Close the command prompt shell and open the OSGeo4W Shell** *The shell
will probaly open in the C: drive. If that is not where your Postgres
database is located, switch to the drive where it is located (for
example, the D: drive)* d:

# 3 Load the geodatabase into the st_sim_demo database. Note: THIS TAKES A LOOOOONG TIME!

ogr2ogr -f “PostgreSQL” PG:“host=localhost port=5432 dbname=st_sim_demo
user=postgres” path_to_the_geodatabase.gdb -overwrite -progress –config
PG_USE_COPY YES

# 4 References

<div id="refs">

</div>

<!--chapter:end:index.Rmd-->
