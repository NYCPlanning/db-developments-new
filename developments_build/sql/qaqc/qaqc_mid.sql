/** QAQC
	JOB_TYPE:
		dem_nb_overlap
    UNITS:
        units_init_null
	    units_init_null
        dup_equal_units
        dup_diff_units
    OCC:
        b_nonres_with_units
	    units_res_accessory
	    b_likely_occ_desc
    CO:
        units_co_prop_mismatch
    STATUS:
        z_incomp_tract_home
**/

DROP TABLE IF EXISTS MID_qaqc;
WITH

JOBNUMBER_all AS(
	SELECT DISTINCT job_number
	FROM MID_devdb
),


JOBNUMBER_null_init AS(
    SELECT job_number
    FROM MID_devdb
    WHERE
    job_type IN ('Demolition' , 'Alteration') 
    AND resid_flag = 'Residential' 
    AND classa_init IS NULL),

JOBNUMBER_null_prop AS(
    SELECT job_number
    FROM MID_devdb
    WHERE
    job_type IN ('New Building' , 'Alteration') 
    AND resid_flag = 'Residential' 
    AND classa_prop IS NULL),   

JOBNUMBER_dup_equal_units AS (
    SELECT a.job_number, b.job_number as dup_equal_units
    FROM MID_devdb a 
    JOIN MID_devdb b 
    ON a.job_type = b.job_type
    AND a.bbl = b.bbl
    AND a.address = b.address
    AND a.classa_net = b.classa_net
    AND a.job_number <> b.job_number
),

JOBNUMBER_dup_diff_units AS (
    SELECT a.job_number, b.job_number as dup_diff_units
    FROM MID_devdb a 
    JOIN MID_devdb b 
    ON a.job_type = b.job_type
    AND a.bbl = b.bbl
    AND a.address = b.address
    AND a.classa_net <> b.classa_net
    AND a.job_number <> b.job_number
),

MATCHES_dup_equal_units AS (
    SELECT a.job_number, b.dup_equal_units
    FROM JOBNUMBER_all a
    LEFT JOIN JOBNUMBER_dup_equal_units b
    ON a.job_number = b.job_number
),


MATCHES_dup_diff_equal_units AS (
    SELECT a.job_number, a.dup_equal_units, b.dup_diff_units
    FROM MATCHES_dup_equal_units a
    LEFT JOIN JOBNUMBER_dup_diff_units b
    ON a.job_number = b.job_number
),

BBL_join AS (
    SELECT 
		a.job_number, 
		a.job_type, 
		a.bin, 
		a.bbl, 
		a.geom, 
		b.geom as bbl_geom
    FROM (
		SELECT * 
		FROM MID_devdb 
		WHERE job_type ~* 'Demolition|New Building'
	) a
    JOIN dcp_mappluto b
    ON a.bbl = b.bbl::bigint::text
),

DEMO AS (
	SELECT * 
	FROM BBL_join
	WHERE job_type = 'Demolition'
),

NB AS (
	SELECT * 
	FROM BBL_join
	WHERE job_type = 'New Building'
),

JOBNUMBER_dem_nb_overlap AS (
    SELECT a.job_number, 
    	b.job_number as dem_nb_overlap
    FROM DEMO a, NB b
	WHERE LEFT(a.bbl, 6)::numeric = LEFT(b.bbl, 6)::numeric
	AND (ST_Within(a.geom, b.bbl_geom) OR ST_Within(b.geom, a.bbl_geom))
),

MATCHES_dem_nb_overlap AS (
    SELECT a.job_number, b.dem_nb_overlap
    FROM JOBNUMBER_all a
    LEFT JOIN JOBNUMBER_dem_nb_overlap b
    ON a.job_number = b.job_number
),

JOBNUMBER_nonres_units AS (
	SELECT job_number 
	FROM MID_devdb
	WHERE resid_flag IS NULL
	AND (classa_prop <> 0 OR classa_init <> 0)
),

JOBNUMBER_accessory AS (
	SELECT job_number
	FROM MID_devdb
	WHERE ((address LIKE '%GAR%' 
					OR job_desc ~* 'pool|shed|gazebo|garage')
			AND (classa_init::numeric IN (1,2) 
					OR classa_prop::numeric IN (1,2)))
	OR ((occ_initial LIKE '%(U)%'
			OR occ_initial LIKE '%(K)%'
			OR occ_proposed LIKE '%(U)%'
			OR occ_proposed LIKE '%(K)%')
		AND (classa_init::numeric > 0 
			OR classa_prop::numeric > 0))
),

JOBNUMBER_b_likely AS (
    SELECT job_number
    FROM MID_devdb
    WHERE (job_type = 'Alteration' 
            AND (occ_initial LIKE '%Residential%' AND occ_proposed LIKE '%Hotel%') 
            OR (occ_initial LIKE '%Hotel%' AND occ_proposed LIKE '%Residential%'))
    OR job_desc ~* CONCAT('Hotel|Motel|Boarding|Hoste|Lodge|UG 5', '|',
                          'Group 5|Grp 5|Class B|SRO|Single room', '|',
                          'Furnished|Rooming unit|Dorm|Transient', '|',
                          'Homeless|Shelter|Group quarter|Beds', '|',
                          'Convent|Monastery|Accommodation|Harassment', '|',
                          'CNH|Settlement|Halfway|Nursing home|Assisted|')
),

JOBNUMBER_co_prop_mismatch AS (
    SELECT job_number
    FROM MID_devdb
    WHERE job_type = 'New Building' 
    AND classa_complt::numeric - classa_prop::numeric > 50
),

JOBNUMBER_incomplete_tract AS (
    SELECT job_number
    FROM MID_devdb
    WHERE tracthomes = 'Y'
    AND job_status LIKE 'Complete'
),

_MID_qaqc AS (
	SELECT a.*,
	    (CASE 
		 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_null_init) THEN 1
		 	ELSE 0
		END) as units_init_null,
	    (CASE 
		 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_null_prop) THEN 1
		 	ELSE 0
		END) as units_prop_null,
	    b.dup_equal_units,
	    b.dup_diff_units,
	    (CASE 
		 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_nonres_units) THEN 1
		 	ELSE 0
		END) as b_nonres_with_units,
	    (CASE 
		 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_accessory) THEN 1
		 	ELSE 0
		END) as units_res_accessory,
	    (CASE 
		 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_b_likely) THEN 1
		 	ELSE 0
		END) as b_likely_occ_desc,
	    (CASE 
		 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_co_prop_mismatch) THEN 1
		 	ELSE 0
		END) as units_co_prop_mismatch,
	    (CASE 
		 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_co_prop_mismatch) THEN 1
		 	ELSE 0
		END) as z_incomp_tract_home
	
	FROM STATUS_qaqc a
	JOIN MATCHES_dup_diff_equal_units b
	ON a.job_number = b.job_number)
	
SELECT a.*,
	b.dem_nb_overlap
INTO MID_qaqc
FROM _MID_qaqc a
JOIN MATCHES_dem_nb_overlap b
ON a.job_number = b.job_number;