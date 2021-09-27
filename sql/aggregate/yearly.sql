/*
DESCRIPTION:
    Creates an unaggregated table as input for the spatial aggregates.
    Includes completions split by year. 
    
INPUTS:
    FINAL_devdb
    LOOKUP_geo
OUTPUTS:
    YEARLY_devdb
*/

DROP TABLE IF EXISTS YEARLY_devdb_{{ decade }};
SELECT 
    job_number,
    boro,
    boro as borocode,
    bctcb20{{ decade }},
    cenblock{{ decade }},
    bct20{{ decade }},
    centract{{ decade }},
    nta20{{ decade }},
    ntaname20{{ decade }},
    comunitydist,
    councildist,

    CASE WHEN complete_year = '2010' AND date_complete > '2010-03-31'::date
            AND job_inactive IS NULL
        THEN classa_net
        ELSE NULL END AS comp2010ap,
    
    {%- for year in years %}
     CASE WHEN complete_year = '{{ year }}' AND job_inactive IS NULL
        THEN classa_net
        ELSE NULL END AS comp{{ year }},
    {% endfor %}

    CASE WHEN date_complete > '2010-03-31'::date AND date_complete < '{{CAPTURE_DATE}}'::date
            AND job_inactive IS NULL
        THEN classa_net
        ELSE NULL END AS since_cen10,

    CASE WHEN job_status = '1. Filed Application'
            AND job_inactive IS NULL
        THEN  classa_net 
        ELSE NULL END as filed, 

    CASE WHEN job_status = '2. Approved Application'
            AND job_inactive IS NULL
        THEN  classa_net 
        ELSE NULL END as approved, 

    CASE WHEN job_status = '3. Permitted for Construction'
            AND job_inactive IS NULL
        THEN  classa_net 
        ELSE NULL END as permitted, 

    CASE WHEN job_status = '9. Withdrawn'
            AND date_lastupdt::date > '2009-12-31'::date
        THEN  classa_net 
        ELSE NULL END as withdrawn, 

    CASE WHEN job_status <> '9. Withdrawn'
            AND job_inactive ~* 'Inactive'
            AND date_lastupdt::date > '2009-12-31'::date
        THEN  classa_net 
        ELSE NULL END as inactive

INTO YEARLY_devdb
FROM FINAL_devdb