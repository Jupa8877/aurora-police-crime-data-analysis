-- staging table
DROP TABLE IF EXISTS stg_crime_offenses;

CREATE TABLE stg_crime_offenses (
  OBJECTID BIGINT
  , INCIDENT_ID VARCHAR(20)
  , OFFENSE_ID VARCHAR(25)
  , OFFENSE_CODE INT
  , OFFENSE_CODE_EXTENSION INT
  , OFFENSE_TYPE_ID VARCHAR(120)
  , OFFENSE_CATEGORY_ID VARCHAR(120)
  , FIRST_OCCURRENCE_DATE VARCHAR(30)
  , LAST_OCCURRENCE_DATE VARCHAR(30)
  , REPORTED_DATE VARCHAR(30)
  , INCIDENT_ADDRESS VARCHAR(255)
  , GEO_X BIGINT
  , GEO_Y BIGINT
  , GEO_LON DECIMAL(10,6)
  , GEO_LAT DECIMAL(10,6)
  , DISTRICT_ID VARCHAR(10)
  , PRECINCT_ID INT
  , NEIGHBORHOOD_ID VARCHAR(120)
  , IS_CRIME TINYINT
  , IS_TRAFFIC TINYINT
  , VICTIM_COUNT INT
  , x DECIMAL(12,6)
  , y DECIMAL(12,6)
) ENGINE=InnoDB;

-- load csv into stg_crime_offenses
LOAD DATA LOCAL INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/ODC_CRIME_OFFENSES_P_-3254178225590307312.csv'
INTO TABLE stg_crime_offenses
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(OBJECTID, INCIDENT_ID, OFFENSE_ID, OFFENSE_CODE, OFFENSE_CODE_EXTENSION,
 OFFENSE_TYPE_ID, OFFENSE_CATEGORY_ID, FIRST_OCCURRENCE_DATE, LAST_OCCURRENCE_DATE,
 REPORTED_DATE, INCIDENT_ADDRESS, GEO_X, GEO_Y, GEO_LON, GEO_LAT, DISTRICT_ID,
 PRECINCT_ID, NEIGHBORHOOD_ID, IS_CRIME, IS_TRAFFIC, VICTIM_COUNT, x, y);
 
 
-- fact table that is ready for analysis
DROP TABLE IF EXISTS fact_crime_offenses;

CREATE TABLE fact_crime_offenses (
	  incident_id VARCHAR(20) NOT NULL
    , offense_id VARCHAR(25) NOT NULL
    , objectid BIGINT
    , offense_code INT
    , offense_code_extension INT
	, offense_type_id VARCHAR(120)
    , offense_category_id VARCHAR(120)
    , first_occurrence_dt DATETIME
    , last_occurrence_dt DATETIME
    , reported_dt DATETIME
    , incident_date DATE -- only dates from first_occurrence_dt
    , incident_address VARCHAR(255)
    , geo_lon DECIMAL(10,6)
    , geo_lat DECIMAL(10,6)
    , geo_x BIGINT
    , geo_y BIGINT
    , district_id VARCHAR(10)
    , precinct_id INT
    , neighborhood_id VARCHAR(120)
    , is_crime TINYINT
    , is_traffic TINYINT
    , victim_count INT
    , x DECIMAL(12,6)
    , y DECIMAL(12,6)
    , PRIMARY KEY (incident_id, offense_id)
    , KEY idx_incident_date (incident_date)
    , KEY idx_reported_dt (reported_dt)
    , KEY idx_district (district_id)
    , KEY idx_neighborhood (neighborhood_id)
    , KEY idx_offense_cat (offense_category_id)
    , KEY idx_offense_type (offense_type_id)
    , KEY idx_geo (geo_lat, geo_lon)
) ENGINE=InnoDB;


ALTER TABLE fact_crime_offenses
  ADD COLUMN reported_date DATE NULL AFTER incident_date;

INSERT INTO fact_crime_offenses (
				incident_id -- Dropped OBJECTID from stg_crime_offenses table
			  , offense_id
              , objectid
              , offense_code
              , offense_code_extension
              , offense_type_id
              , offense_category_id
              , first_occurrence_dt
              , last_occurrence_dt
              , reported_dt
              , incident_date
              , reported_date
              , incident_address
              , geo_lon, geo_lat
              , geo_x
              , geo_y
              , district_id
              , precinct_id
              , neighborhood_id
              , is_crime
              , is_traffic
              , victim_count
              , x
              , y
)
SELECT s.INCIDENT_ID
	 , s.OFFENSE_ID
     , s.OBJECTID
     , s.OFFENSE_CODE
     , s.OFFENSE_CODE_EXTENSION
     , s.OFFENSE_TYPE_ID
     , s.OFFENSE_CATEGORY_ID
     -- transfered data type to datetime
     , STR_TO_DATE(
		NULLIF(s.FIRST_OCCURRENCE_DATE,''), '%m/%d/%Y %h:%i:%s %p') AS first_occurrence_dt
	 , STR_TO_DATE(NULLIF(s.LAST_OCCURRENCE_DATE,''), '%m/%d/%Y %h:%i:%s %p') AS last_occurrence_dt
     , STR_TO_DATE(NULLIF(s.REPORTED_DATE,''), '%m/%d/%Y %h:%i:%s %p') AS reported_dt
     -- transfer incidence dt to incidence date for analysis
     , DATE(STR_TO_DATE(NULLIF(s.FIRST_OCCURRENCE_DATE,''), '%m/%d/%Y %h:%i:%s %p')) AS incident_date
     -- transfer reported_dt to incidence date for analysis
     , DATE(STR_TO_DATE(NULLIF(s.REPORTED_DATE,''), '%m/%d/%Y %h:%i:%s %p')) AS reported_date
     , s.INCIDENT_ADDRESS
     , s.GEO_LON
     , s.GEO_LAT
     , s.GEO_X
     , s.GEO_Y
     , s.DISTRICT_ID
     , s.PRECINCT_ID
     , s.NEIGHBORHOOD_ID
     , s.IS_CRIME
     , s.IS_TRAFFIC
     , s.VICTIM_COUNT
     , s.x
     , s.y
FROM stg_crime_offenses s
WHERE s.INCIDENT_ID IS NOT NULL
  AND s.OFFENSE_ID IS NOT NULL;

 
