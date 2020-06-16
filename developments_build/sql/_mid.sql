/*
DESCRIPTION:
    Merging INIT_devdb with (STATUS_Q_devdb, CO_devdb, UNITS_devdb, OCC_devdb)
    JOIN KEY: job_number

INPUTS: 

    INIT_devdb (
        * job_number,
        ...
    )

    STATUS_Q_devdb (
        * job_number,
        date_permittd,
        _complete_year,
        _complete_qrtr
    )

    CO_devdb (
        * job_number,
        _complete_year,
        _complete_qrtr,
        date_complete,
        co_latest_certtype, 
        co_latest_units
    )

    UNITS_devdb (
        * job_number,
        classa_init,
        classa_prop,
        hotel_init,
	    hotel_prop,
	    otherb_init,
	    otherb_prop,
        classa_net
    )

    OCC_devdb (
        * job_number,
        occ_initial,
        occ_proposed,
        resid_flag
    )

OUTPUTS: 
    _MID_devdb (
        * job_number,
        date_permittd,
        _complete_year,
        _complete_qrtr,
        date_complete,
        co_latest_certtype, 
        co_latest_units,
        classa_init,
        classa_prop,
        hotel_init,
	    hotel_prop,
	    otherb_init,
	    otherb_prop,
        classa_net,
        classa_complt_diff,
        occ_initial,
        occ_proposed,
        resid_flag,
        nonres_flag
        ...
    )
*/
DROP TABLE IF EXISTS _MID_devdb;
WITH
JOIN_date_permittd as (
    SELECT
        a.*,
        b.date_permittd,
        b.permit_year,
        b.permit_qrtr,
        b._complete_year as complete_year_A1_NB,
        b._complete_qrtr as complete_qrtr_A1_NB
    FROM INIT_devdb a
    LEFT JOIN STATUS_Q_devdb b
    ON a.job_number = b.job_number
), 
JOIN_co as (
    SELECT 
        a.*,
        -- For new buildings and alterations, this is defined as the year of the 
        -- first certificate of occupancy issuance. For demolitions, this is the 
        -- year that the demolition was permitted
        (CASE WHEN a.job_type = 'Demolition'
            THEN b._complete_year 
        ELSE a.complete_year_A1_NB END) as _complete_year,
        (CASE WHEN a.job_type = 'Demolition'
            THEN b._complete_qrtr 
        ELSE a.complete_qrtr_A1_NB END) as _complete_qrtr,
        b.date_complete,
        b.co_latest_certtype,
        b.co_latest_units::numeric
    FROM JOIN_date_permittd a
    LEFT JOIN CO_devdb b
    ON a.job_number = b.job_number
),
JOIN_units as (
    SELECT
        a.*,
        b.classa_net,
        b.classa_init,
        b.classa_prop,
        b.hotel_init,
	    b.hotel_prop,
	    b.otherb_init,
	    b.otherb_prop,
        (CASE
            WHEN b.classa_net != 0 
                THEN a.co_latest_units/b.classa_net
            ELSE NULL
        END) as classa_complt_pct,
        b.classa_net - a.co_latest_units as classa_complt_diff
    FROM JOIN_co a
    LEFT JOIN UNITS_devdb b
    ON a.job_number = b.job_number
),
JOIN_occ as (
    SELECT
        a.*,
        b.occ_initial,
        b.occ_proposed,
        b.resid_flag,
        b.nonres_flag
    FROM JOIN_units a
    LEFT JOIN OCC_devdb b
    ON a.job_number = b.job_number
) 
SELECT *
INTO _MID_devdb
FROM JOIN_occ;
