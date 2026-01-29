
-- Monthly incident trend (occurrence-based)
SELECT DATE_FORMAT(incident_date, '%Y-%m') AS ym
	 , COUNT(*) AS incidents
FROM fact_crime_offenses
WHERE incident_date IS NOT NULL
GROUP BY ym
ORDER BY ym;

-- Month over month (MoM) incidents change and percent change
WITH m AS (
	SELECT DATE_FORMAT(incident_date, '%Y-%m') AS ym
		 , COUNT(*) AS incidents
	FROM fact_crime_offenses
	WHERE incident_date IS NOT NULL
	GROUP BY ym
)
SELECT ym
	 , incidents
     , LAG(incidents) OVER (ORDER BY ym) AS prev_incidents
     , ROUND(100 * (incidents - LAG(incidents) OVER (ORDER BY ym)) / NULLIF(LAG(incidents) OVER (ORDER BY ym), 0), 2) AS mom_change_pct
FROM m
ORDER BY ym;

--  Recent 30 days vs previous 30 days total incidents changes (near real-time comparison)
SELECT SUM(incident_date >= CURDATE() - INTERVAL 30 DAY) AS last_30
	 , SUM(incident_date BETWEEN CURDATE() - INTERVAL 60 DAY AND CURDATE() - INTERVAL 31 DAY) AS prev_30
     , (SUM(incident_date >= CURDATE() - INTERVAL 30 DAY) -
		SUM(incident_date BETWEEN CURDATE() - INTERVAL 60 DAY AND CURDATE() - INTERVAL 31 DAY)) AS delta
FROM fact_crime_offenses
WHERE incident_date IS NOT NULL;

-- Day of week crime pattern
SELECT DAYNAME(incident_date) AS day_name
	 , COUNT(*) AS incidents
FROM fact_crime_offenses
WHERE incident_date IS NOT NULL
GROUP BY day_name
ORDER BY incidents DESC;

-- Hour-of-day crime pattern (supports nighttime peak analysis)
SELECT HOUR(first_occurrence_dt) AS hour_of_day
	 , COUNT(*) AS incidents
FROM fact_crime_offenses
WHERE first_occurrence_dt IS NOT NULL
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- District incidents totals (high-level resource planning)
SELECT district_id
	 , COUNT(*) AS incidents
FROM fact_crime_offenses
GROUP BY district_id
ORDER BY incidents DESC;

-- District incidents totals for the last 30 days (rapid situational awareness)
SELECT district_id
	 , COUNT(*) AS incidents_last_30
FROM fact_crime_offenses
WHERE incident_date >= CURDATE() - INTERVAL 30 DAY
GROUP BY district_id
ORDER BY incidents_last_30 DESC;

-- Top 20 crime neighborhoods (hotspot candidates)
SELECT neighborhood_id
	 , COUNT(*) AS incidents
FROM fact_crime_offenses
GROUP BY neighborhood_id
ORDER BY incidents DESC
LIMIT 20;

-- Top 10 offense categories
SELECT offense_category_id
	 , COUNT(*) AS incidents
FROM fact_crime_offenses
GROUP BY offense_category_id
ORDER BY incidents DESC
LIMIT 10;

-- Top 10 offense types
SELECT offense_type_id
	 , COUNT(*) AS incidents
FROM fact_crime_offenses
GROUP BY offense_type_id
ORDER BY incidents DESC
LIMIT 10;

-- Offense category share % by month
WITH m AS (
	SELECT DATE_FORMAT(incident_date, '%Y-%m') AS ym
		 , offense_category_id
         , COUNT(*) AS incidents
  FROM fact_crime_offenses
  WHERE incident_date IS NOT NULL
  GROUP BY ym, offense_category_id
)
, t AS (
	SELECT ym
		 , SUM(incidents) AS total_incidents
	FROM m
	GROUP BY ym
)
SELECT m.ym
	 , m.offense_category_id
     , m.incidents
     , ROUND(100 * m.incidents / NULLIF(t.total_incidents, 0), 2) AS share_pct
FROM m
JOIN t USING (ym)
ORDER BY m.ym, share_pct DESC;

-- District x Offense Category (where certain categories concentrate)
SELECT district_id
	 , offense_category_id
     , COUNT(*) AS incidents
FROM fact_crime_offenses
GROUP BY district_id, offense_category_id
HAVING COUNT(*) >= 100
ORDER BY incidents DESC;

-- Nighttime share by district (20:00–04:00)
WITH d AS (
	SELECT district_id
		 , COUNT(*) AS total_incidents
         , SUM(CASE
					WHEN HOUR(first_occurrence_dt) >= 20 OR HOUR(first_occurrence_dt) <= 4 THEN 1
                    ELSE 0
				END) AS night_incidents
	FROM fact_crime_offenses
	WHERE first_occurrence_dt IS NOT NULL
	GROUP BY district_id
)
SELECT district_id
	 , total_incidents
     , night_incidents
     , ROUND(100 * night_incidents / NULLIF(total_incidents, 0), 2) AS night_share_pct
FROM d
ORDER BY night_share_pct DESC;

-- Hotspot grid (Accuracy to two decimal places)
SELECT ROUND(geo_lat, 2) AS lat_grid
	 , ROUND(geo_lon, 2) AS lon_grid
     , COUNT(*) AS incidents
FROM fact_crime_offenses
WHERE geo_lat IS NOT NULL AND geo_lon IS NOT NULL
GROUP BY lat_grid, lon_grid
HAVING COUNT(*) >= 50
ORDER BY incidents DESC
LIMIT 50;

-- Emerging hotspots: last 30 days vs previous 30 days (grid delta)
WITH grid_60 AS (
	SELECT ROUND(geo_lat, 2) AS lat_grid
		 , ROUND(geo_lon, 2) AS lon_grid
         , SUM(incident_date >= CURDATE() - INTERVAL 30 DAY) AS last_30
         , SUM(incident_date BETWEEN CURDATE() - INTERVAL 60 DAY AND CURDATE() - INTERVAL 31 DAY) AS prev_30
  FROM fact_crime_offenses
  WHERE incident_date IS NOT NULL
    AND geo_lat IS NOT NULL AND geo_lon IS NOT NULL
  GROUP BY lat_grid, lon_grid
)
SELECT lat_grid
	 , lon_grid
     , last_30
     , prev_30
     , (last_30 - prev_30) AS difference
     , ROUND(100 * (last_30 - prev_30) / NULLIF(prev_30, 0), 2) AS growth_pct
FROM grid_60
WHERE last_30 >= 10
ORDER BY difference DESC
LIMIT 30;