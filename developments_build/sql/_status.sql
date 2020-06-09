/*
DESCRIPTION:
    This script is created to assign/recode the field "status" 
    
INPUTS:
    MID_devdb (
        * job_number,
        job_type character varying,
        status_date date,
        status_p date,
        status_q date,
        _status text,
        year_complete text,
        co_latest_units numeric,
        co_latest_certtype text,
        units_complete numeric,
        units_incomplete numeric,
        units_net numeric,
        address text,
        occ_prop text
    )

    housing_input_lookup_status (
        dobstatus,
        dcpstatus
    )

OUTPUTS:
    STATUS_devdb (
        * job_number character varying,
        job_type character varying,
        status character varying,
        status_date date,
        status_q date,
        year_complete text,
        units_complete numeric,
        units_incomplete numeric,
        units_net numeric,
        address text,
        occ_prop text,
        x_inactive text,
        x_dcpedited text,
        x_reason text
    )

IN PREVIOUS VERSION: 
    status.sql
    year_complete.sql
    unitscomplete.sql
*/
DROP TABLE IF EXISTS STATUS_devdb;
WITH
STATUS_translate as (
    SELECT 
        a.job_number,
        a.job_type,
        a.status_q,
        a.year_complete,
        a.units_net,
        a.co_latest_units,
        a.status_date,
        a.address,
        a.occ_prop,
        (CASE
            WHEN a.job_type = 'New Building'
                AND a.co_latest_certtype = 'T- TCO'
                AND (
                    (a.units_complete_pct < 0.8 AND a.units_net >= 20) OR 
                    (a.units_complete_diff >= 5 AND a.units_net BETWEEN 5 AND 19)
                )
                THEN 'Partial complete'

            WHEN a.job_type = 'Demolition' 
                AND b.dcpstatus IN ('Complete','Permit issued') 
                THEN 'Complete (demolition)'

            WHEN a.x_withdrawal IN ('W', 'C')
                THEN 'Withdrawn'

            WHEN status_p IS NOT NULL
                THEN 'In progress'

            WHEN status_q IS NOT NULL
                THEN 'Permit issued'

            ELSE b.dcpstatus 
        END) as status
    FROM MID_devdb a
    LEFT JOIN housing_input_lookup_status b
    ON a._status = b.dobstatus
),
DRAFT_STATUS_devdb as (
    SELECT
        job_number,
        job_type,
        status,
        status_q,
        status_date::date,
        units_net,
        address,
        occ_prop,
        -- update year_compelte based on job_type and status
        (CASE
            WHEN job_type = 'Demolition'
                OR status = 'Withdrawn'
                THEN NULL
            ELSE year_complete
        END) as year_complete,

        -- Assign units_complete based on status
        (CASE
            WHEN status LIKE 'Complete%' 
                THEN units_net
            WHEN status = 'Partial complete' 
                THEN co_latest_units
            ELSE NULL
        END) as units_complete,

        -- Assing units_incomplete
        (CASE
            WHEN status LIKE 'Complete%' 
                THEN NULL
            WHEN status = 'Partial complete'
                THEN units_net-co_latest_units
            ELSE units_net
        END) units_incomplete
    FROM STATUS_translate
)
SELECT
    job_number,
    job_type,
    status,
    status_date,
    status_q,
    year_complete,
    units_complete,
    units_incomplete,
    units_net,
    address,
    occ_prop,
    (CASE 
        WHEN (CURRENT_DATE - status_date)/365 >= 2 
            AND status = 'In progress (last plan disapproved)'
            THEN 'Inactive'
        WHEN (CURRENT_DATE - status_date)/365 >= 3 
            AND status in ('Filed', 'In progress')
            THEN 'Inactive'
        WHEN status = 'Withdrawn'
            THEN 'Inactive'
    END) as x_inactive,
    NULL as x_dcpedited,
    NULL as x_reason
INTO STATUS_devdb
FROM DRAFT_STATUS_devdb;

WITH completejobs AS (
	SELECT address, job_type, status_date, status
	FROM STATUS_devdb
	WHERE units_net::numeric > 0
	AND status LIKE 'Complete%')
UPDATE STATUS_devdb a 
SET x_inactive = 'Inactive'
FROM completejobs b
WHERE a.address = b.address
	AND a.job_type = b.job_type
	AND a.status NOT LIKE 'Complete%'
	AND a.status_date::date < b.status_date::date
	AND a.status <> 'Withdrawn'
  	AND a.occ_prop <> 'Garage/Miscellaneous';

/* 
CORRECTIONS
    units_complete
    units_incomplete
*/

UPDATE STATUS_devdb a
SET units_complete = TRIM(b.new_value)::numeric,
	x_dcpedited = coalesce(x_dcpedited, '')||'units_complete-',
	x_reason = b.reason
FROM housing_input_research b
WHERE a.job_number=b.job_number
AND b.field = 'units_complete'
AND (a.units_complete=b.old_value::numeric 
    OR (a.units_complete IS NULL
        AND b.old_value IS NULL));

UPDATE STATUS_devdb a
SET units_incomplete = TRIM(b.new_value)::numeric,
	x_dcpedited = coalesce(x_dcpedited, '')||'units_incomplete-',
	x_reason = b.reason
FROM housing_input_research b
WHERE a.job_number=b.job_number
AND b.field = 'units_incomplete'
AND (a.units_incomplete::numeric=b.old_value::numeric 
    OR (a.units_incomplete IS NULL
        AND b.old_value IS NULL));