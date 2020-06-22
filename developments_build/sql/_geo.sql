/*
DESCRIPTION:
    1. Assigning missing geoms for _GEO_devdb and create GEO_devdb
    2. Apply research corrections on (longitude, latitude, geom)

INPUTS: 
    _INIT_devdb (
        * uid,
        ...
    )

    _GEO_devdb (
        * uid,
        ...
    )

    housing_input_research (
        * job_number
    )

    dcp_mappluto (
        * bbl,
        geom
    )

OUTPUT 
    GEO_devdb (
        * uid,
        job_number
        geo_bbl text,
        geo_bin text,
        geo_address_numbr text,
        geo_address_street text,
        geo_address text,
        geo_zipcode text,
        geo_boro text,
        geo_cd text,
        geo_council text,
        geo_ntacode2010 text,
        geo_censusblock2010 text,
        geo_censustract2010 text,
        geo_csd text,
        geo_policeprct text,
        geo_latitude double precision,
        geo_longitude double precision,
        latitude double precision,
        longitude double precision,
        geom geometry,
        geomsource text
    )

IN PREVIOUS VERSION: 
    geo_merge.sql
    geoaddress.sql
    geombbl.sql
    latlon.sql
    dedupe_job_number.sql
    dropmillionbin.sql
*/
DROP TABLE IF EXISTS GEO_devdb;
WITH
DRAFT as (
    SELECT
        distinct
        a.uid,
        a.job_number,
		    a.bbl,
        a.bin,
        a.date_lastupdt,
        a.job_desc,
        b.geo_bbl,
        NULLIF(RIGHT(b.geo_bin,6),'000000') as geo_bin,
        b.geo_address_numbr,
        b.geo_address_street,
        concat(
            trim(b.geo_address_numbr),' ',
            trim(b.geo_address_street)
        )as geo_address,
        b.geo_zipcode,
        b.geo_boro, 
        b.geo_cd,
        b.geo_council,
        b.geo_ntacode2010, 
        b.geo_censusblock2010, 
        b.geo_censustract2010,
        b.geo_csd,
        b.geo_policeprct,
        b.geo_puma,
        b.geo_firedivision,
        b.geo_firebattalion,
        b.geo_firecompany,
        (CASE WHEN b.mode = 'tpad' then NULL 
        ELSE b.latitude::double precision END) as geo_latitude,
        (CASE WHEN b.mode = 'tpad' then NULL 
        ELSE b.longitude::double precision END) as geo_longitude,
        b.mode
	FROM _INIT_devdb a
	LEFT JOIN _GEO_devdb b
	ON a.uid = b.uid
),
GEOM_geosupport as (
    SELECT distinct
        uid,
        job_number,
		bbl,
        bin,
        geo_bbl,
        geo_bin,
        ST_SetSRID(ST_Point(geo_longitude,geo_latitude),4326) as geom,
        (CASE WHEN geo_longitude IS NOT NULL 
		 THEN 'Lat/Long geosupport' END) as geomsource
    FROM DRAFT
),
GEOM_dob_bin_bldgfootprints as (
    SELECT distinct
        a.uid,
        a.job_number,
		a.bbl,
        a.bin,
        a.geo_bbl,
        a.geo_bin,
        coalesce(a.geom, ST_Centroid(b.wkb_geometry)) as geom,
        (CASE 
		 	WHEN a.geomsource IS NOT NULL 
		 		THEN a.geomsource 
		 	WHEN a.geom IS NULL 
		 		AND b.wkb_geometry IS NOT NULL 
		 		THEN 'BIN DOB buildingfootprints'
		END) as geomsource
    FROM GEOM_geosupport a
    LEFT JOIN doitt_buildingfootprints b
    ON a.bin::text = b.bin::text
),
GEOM_geo_bin_bldgfootprints as (
	SELECT distinct
        a.uid,
        a.job_number,
		a.bbl,
        a.bin,
        a.geo_bbl,
        a.geo_bin,
        coalesce(a.geom, ST_Centroid(b.wkb_geometry)) as geom,
        (CASE 
          WHEN a.geomsource IS NOT NULL 
            THEN a.geomsource 
          WHEN a.geom IS NULL 
            AND b.wkb_geometry IS NOT NULL 
            THEN 'BIN DCP geosupport'
		END) as geomsource
    FROM GEOM_dob_bin_bldgfootprints a
    LEFT JOIN doitt_buildingfootprints b
    ON a.geo_bin = b.bin
),
GEOM_dob_bbl_mappluto as (
	SELECT distinct
        a.uid,
        a.job_number,
		a.bbl,
        a.bin,
        a.geo_bbl,
        coalesce(a.geom, ST_Centroid(b.wkb_geometry)) as geom,
        (CASE 
          WHEN a.geomsource IS NOT NULL 
            THEN a.geomsource 
          WHEN a.geom IS NULL 
		 		AND b.wkb_geometry IS NOT NULL 
		 		THEN 'BBL DOB MapPLUTO'
		END) as geomsource
    FROM GEOM_geo_bin_bldgfootprints a
    LEFT JOIN dcp_mappluto b
    ON a.bbl = b.bbl::numeric::bigint::text
), 
buildingfootprints_historical as (
    SELECT 
        bin, 
        ST_Union(wkb_geometry) as wkb_geometry
    FROM doitt_buildingfootprints_historical
    GROUP BY bin
),
GEOM_dob_bin_bldgfp_historical as (
    SELECT distinct
        a.uid,
        a.job_number,
        coalesce(a.geom, ST_Centroid(b.wkb_geometry)) as geom,
        (CASE 
		 	WHEN a.geomsource IS NOT NULL 
		 		THEN a.geomsource 
		 	WHEN a.geom IS NULL 
		 		AND b.wkb_geometry IS NOT NULL 
		 		THEN 'BIN DOB buildingfootprints (historical)'
		END) as geomsource
    FROM GEOM_dob_bbl_mappluto a
    LEFT JOIN buildingfootprints_historical b
    ON a.bin::text = b.bin::text
)
SELECT
    distinct a.*,
    ST_Y(b.geom) as latitude,
    ST_X(b.geom) as longitude,
    b.geom,
    b.geomsource
INTO GEO_devdb
FROM DRAFT a
LEFT JOIN GEOM_dob_bin_bldgfp_historical b
ON a.uid = b.uid;

/* 
CORRECTIONS

    longitude
    latitude
    geom
    
*/
WITH LONLAT_corrections as (
    SELECT 
        a.job_number,
        coalesce(a.reason, b.reason) as reason,
        ST_SetSRID(ST_MakePoint(a.old_lon, b.old_lat), 4326) as old_geom,
        ST_SetSRID(ST_MakePoint(a.new_lon, b.new_lat), 4326) as new_geom
    FROM (
        SELECT 
            job_number,
            reason,
            old_value::double precision as old_lon, 
            new_value::double precision as new_lon
        FROM housing_input_research
        WHERE field = 'longitude'
    ) a LEFT JOIN (
        SELECT 
            job_number, 
            reason,
            old_value::double precision as old_lat, 
            new_value::double precision as new_lat
        FROM housing_input_research
        WHERE field = 'latitude'
    ) b ON a.job_number = b.job_number
),
GEOM_corrections as (
    SELECT
        a.job_number,
        a.old_geom,
        a.new_geom,
        a.reason,
        st_distance(a.new_geom, b.geom) as distance,
        get_bbl(b.geom) as bbl
    FROM LONLAT_corrections a
    LEFT JOIN GEO_devdb b
    ON a.job_number = b.job_number
)
UPDATE GEO_devdb a
SET latitude = ST_Y(b.new_geom),
    longitude = ST_X(b.new_geom),
    geom = b.new_geom,
    geomsource = 'Lat/Long DCP'
FROM GEOM_corrections b
WHERE a.job_number=b.job_number
AND (b.distance < 10 AND b.bbl IS NULL);

WITH CORR_target as (
    SELECT a.job_number, 
		COALESCE(b.reason, 'NA') as reason,
		b.edited_date
	FROM _INIT_devdb a, housing_input_research b
	WHERE a.job_number=b.job_number
    AND a.job_number in (
        SELECT distinct job_number
        FROM GEO_devdb 
        WHERE geomsource = 'Lat/Long DCP')
)
UPDATE CORR_devdb a
SET x_dcpedited = array_append(x_dcpedited, 'geom'),
	dcpeditfields = array_append(dcpeditfields, json_build_object(
		'field', 'geom', 'reason', b.reason, 
		'edited_date', b.edited_date
	))
FROM CORR_target b
WHERE a.job_number=b.job_number;