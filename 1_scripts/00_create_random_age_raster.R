
library(sf)
library(terra)
library(tidyverse)
library(RPostgreSQL) 


# Enter the username and password without putting it into your code
# Note: Once you enter these, they will be visible in your R environment, so I remove them after connecting to the database
username <- rstudioapi::askForPassword("Database username") # Postgres username (usually 'postgres')
password <- rstudioapi::askForPassword("Database password") # Postgres password 
port <- rstudioapi::askForPassword("Database port") # Postgres port (usually 5432) 
dbname <- rstudioapi::askForPassword("Database name") # The name of the postgres database where the age file is stored is stored
host <- rstudioapi::askForPassword("Host name") # The postgres host (usually 'localhost')
table <- rstudioapi::askForPassword("Table name") # The name of the table where the age data is kept 
table_geometry <- rstudioapi::askForPassword("Geometry column name") # The geometry column for the table 

pg = dbDriver("PostgreSQL")
# Local Postgres.app database; no password by default
# Of course, you fill in your own database information here.
con = dbConnect(pg, user = username, password = password,
                host = host, port = port, dbname = dbname)
rm(list = c("username", "password", "dbname", "host", "port")) 

fmu_l3 <- st_read("0_data/processed/shapefiles/fmu_l3.shp")

veg_l3 <- st_read(con, query = paste0("SELECT * FROM ", table, " WHERE ST_Intersects(", table, ".", table_geometry, ", (SELECT geometry FROM fmu_l3 WHERE fmu_name = 'L3'));"))
rm(list = c("table", "table_geometry")) 

veg_l3$age <- 2023 - veg_l3$Origin_Year
veg_l3$age <- ifelse(veg_l3$age < 0, NA, veg_l3$age) 
hist(veg_l3$age)


dep_l3 <- rast("0_data/processed/rasters/dep_l3_hart.tif")


age_l3 <- crop(rasterize(vect(veg_l3), y = dep_l3, field = "age"), vect(fmu_l3), mask = TRUE)
plot(age_l3)
writeRaster(age_l3, filename = "0_data/processed/rasters/abmi_age_l3.tif")



# Get the distribution of ages for each habitat type 
f <- freq(dep_l3)
a <- na.omit(data.frame(values(dep_l3), values(age_l3)))

age_dist <- lapply(1:nrow(f), function(i){
  data.frame(a$age) %>% filter(a$ep_code == f$value[i])
})
names(age_dist) <- f$value

age_values <- data.frame(fid = 1:length(values(dep_l3$ep_code)), ep_code = values(dep_l3$ep_code)) 

age_random <- do.call(rbind, lapply(1:length(age_dist), function(x){
  t <- age_values %>% filter(ep_code == as.numeric(names(age_dist))[x])
  t$age <- sample(age_dist[[x]]$a.age, nrow(t), replace = TRUE)
  return(t)
})) %>% left_join(x = age_values, by = "fid")

age_l3_random <- age_l3
values(age_l3_random) <- age_random$age 

# Convert the dep_l3 numeric values to the Hart ep_codes 
dep_lookup <- read.csv("0_data/st-sim/dep_lookup.csv") 

convert <- data.frame(value = f$value, ep_code = dep_lookup %>% distinct(ep_code_hart) %>% 
                        select(ep_code_hart) %>% arrange(ep_code_hart))
convert_2 <- data.frame(numeric_code = values(dep_l3$ep_code), ep_code_hart = convert$ep_code_hart[match(values(dep_l3$ep_code), convert$value)])

values(dep_l3) <- convert_2$ep_code_hart
writeRaster(age_l3_random, "0_data/processed/rasters/age_l3_random.tif")
writeRaster(dep_l3, "0_data/processed/rasters/dep_l3_hart.tif")















