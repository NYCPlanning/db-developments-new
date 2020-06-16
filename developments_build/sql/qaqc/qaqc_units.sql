/** QAQC
	units_init_null
	units_init_null
    b_large_alt_reduction
    outlier_nb_500plus
    outlier_demo_20plus
    outlier_top_alt_increase
    outlier_top_alt_decrease
    dup_equal_units
    dup_diff_units
**/

WITH 

JOBNUMBER_null_init AS(
    SELECT job_number
    FROM UNITS_devdb
    WHERE
    job_type IN ('Demolition' , 'Alteration') 
    AND resid_flag = 'Residential' 
    AND units_init IS NULL),

JOBNUMBER_null_prop AS(
    SELECT job_number
    FROM UNITS_devdb
    WHERE
    job_type IN ('New Building' , 'Alteration' 
    AND resid_flag = 'Residential' 
    AND units_prop IS NULL),   

JOBNUMBER_large_alt AS(
    SELECT job_number
    FROM UNITS_devdb
    WHERE
    job_type = 'Alteration'
    AND classa_net::numeric < -5
),

JOBNUMBER_large_nb AS(
    SELECT job_number
    FROM UNITS_devdb
    WHERE
    job_type = 'New building'
    AND classa_prop::numeric > 499
),

JOBNUMBER_large_demo AS(
    SELECT job_number
    FROM UNITS_devdb
    WHERE
    job_type = 'Demolition'
    AND classa_init::numeric > 19
),

JOBNUMBER_top_alt_inc AS(
    SELECT job_number
    FROM UNITS_devdb
    WHERE
    job_type = 'Alteration'
    ORDER BY classa_net DESC
    LIMIT 20
),

JOBNUMBER_top_alt_dec AS(
    SELECT job_number
    FROM UNITS_devdb
    WHERE
    job_type = 'Alteration'
    ORDER BY classa_net ASC
    LIMIT 20
),
-- Need bbl
JOBNUMBER_dup_equal_units AS (
    SELECT a.job_number
    FROM UNITS_devdb a 
    JOIN UNITS_devdb b 
    ON a.job_type = b.job_type
    AND a.bbl = b.bbl
    AND a.address = b.address
    AND a.classa_net = b.classa_net
    AND a.job_number <> b.job_number
),

JOBNUMBER_dup_diff_units AS (
    SELECT a.job_number
    FROM UNITS_devdb a 
    JOIN UNITS_devdb b 
    ON a.job_type = b.job_type
    AND a.bbl = b.bbl
    AND a.address = b.address
    AND a.classa_net <> b.classa_net
    AND a.job_number <> b.job_number
)

SELECT a.*,
    (CASE 
	 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_null_init) THEN 1
	 	ELSE 0
	END) as units_init_null,
    (CASE 
	 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_null_prop) THEN 1
	 	ELSE 0
	END) as units_init_null,
    (CASE 
	 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_large_alt) THEN 1
	 	ELSE 0
	END) as b_large_alt_reduction,
    (CASE 
	 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_large_nb) THEN 1
	 	ELSE 0
	END) as outlier_nb_500plus,
    (CASE 
	 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_large_demo) THEN 1
	 	ELSE 0
	END) as outlier_demo_20plus,
    (CASE 
	 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_top_alt_inc) THEN 1
	 	ELSE 0
	END) as outlier_top_alt_increase,
    (CASE 
	 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_top_alt_dec) THEN 1
	 	ELSE 0
	END) as outlier_top_alt_decrease,
    (CASE 
	 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_top_alt_dec) THEN 1
	 	ELSE 0
	END) as greatest_alt_net_dec,
    (CASE 
	 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_dup_equal_units) THEN 1
	 	ELSE 0
	END) as dup_equal_units,
    (CASE 
	 	WHEN a.job_number IN (SELECT job_number FROM JOBNUMBER_dup_diff_units) THEN 1
	 	ELSE 0
	END) as dup_diff_units

INTO UNITS_qaqc
FROM INIT_qaqc a;