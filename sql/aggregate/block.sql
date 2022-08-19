DROP TABLE IF EXISTS AGGREGATE_block_{{ decade }};
SELECT 
    boro,
    bctcb{{ decade }},
    cenblock{{ decade }},
    SUM(comp2010ap) as comp2010ap,

    {%- for year in years %}

        SUM(comp{{year}}) as comp{{year}},
        
    {% endfor %}

    -- SUM(since_cen10) as since_cen10,
    SUM(filed) as filed,
    SUM(approved) as approved,
    SUM(permitted) as permitted,
    SUM(withdrawn) as withdrawn,
    SUM(inactive) as inactive

    -- {% if decade == '2010' %}

    --     ,SUM(census_units10.cenunits10) as cenunits10
    --     ,SUM(COALESCE(YEARLY_devdb_{{ decade }}.since_cen10, 0) + COALESCE(census_units10.cenunits10, 0)) as total
    
    -- {% endif %}

INTO AGGREGATE_block_{{ decade }}
FROM YEARLY_devdb_{{ decade }}

-- {% if decade == '2010' %}

--     LEFT JOIN census_units10
--     ON YEARLY_devdb_{{ decade }}.cenblock2010 = census_units10.cenblock10

-- {% endif %}

GROUP BY 
    boro,
    bctcb{{ decade }},
    cenblock{{ decade }}