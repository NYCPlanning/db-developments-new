DROP TABLE IF EXISTS corrections_applied;
CREATE TABLE corrections_applied (
	record_id 		text,
	field 	  		text,
	current_value 	text,
	old_value 		text,
	new_value 		text
);

DROP TABLE IF EXISTS corrections_not_applied;
CREATE TABLE corrections_not_applied (
	record_id 		text,
	field 	  		text,
	current_value 	text,
	old_value 		text,
	new_value 		text
);

/* 
Procedure to apply a single correction:
- Identifies data type of field to correct
- Identifies reference field for old_value (for hotel and otherb, reference is classa)
- Compares current value of reference field with new_value to see if correction is applicable
- If applicable, applies correction and adds to 'corrections_applied' table
- If not applicable, adds to 'corrections_not_applied'
*/
DROP PROCEDURE IF EXISTS correction;
CREATE OR REPLACE PROCEDURE correction (
    _table text,
    _job_number text,
    _field text,
    _old_val text,
    _new_val text
) AS $BODY$
DECLARE
	ref_field text;
    field_type text;
    current_val text;
    applicable boolean;
BEGIN
	EXECUTE format($n$
        SELECT pg_typeof(a.%1$I) FROM %2$I a LIMIT 1;
    $n$, _field, _table) INTO field_type;
	
	SELECT 
	(CASE
		WHEN _field IN ('hotel_init', 'otherb_init') THEN 'classa_init' 
        WHEN _field IN ('hotel_prop', 'otherb_prop') THEN 'classa_prop'
        ELSE _field
    END) INTO  ​ref_field;
	
    EXECUTE format($n$
        SELECT pg_typeof(a.%1$I) FROM %2$I a LIMIT 1;
    $n$, ref_field, _table) INTO field_type;

    EXECUTE format($n$
        SELECT a.%1$I::text FROM %2$I a WHERE a.job_number = %3$L;
    $n$, ref_field, _table, _job_number) INTO current_val;

    EXECUTE format($n$
        SELECT %1$L::%3$s = %2$L::%3$s 
        OR (%1$L IS NULL AND %2$L IS NULL)
    $n$, current_val, _old_val, field_type) INTO applicable;


    IF applicable THEN 
        RAISE NOTICE 'Applying Correction';
        EXECUTE format($n$
            UPDATE %1$I SET %2$I = %3$L::%4$s WHERE job_number = %5$L;
            $n$, _table, _field, _new_val, field_type, _job_number);

        EXECUTE format($n$
            DELETE FROM corrections_applied WHERE job_number = %1$L AND field = %2$L;
            INSERT INTO corrections_applied VALUES (%1$L, %2$L, %3$L, %4$L, %5L);
            $n$, _job_number, _field, current_val, _old_val, _new_val);
    ELSE 
        RAISE NOTICE 'Cannot Apply Correction';
        EXECUTE format($n$
            DELETE FROM corrections_not_applied WHERE job_number = %1$L AND field = %2$L;
            INSERT INTO corrections_not_applied VALUES (%1$L, %2$L, %3$L, %4$L, %5L);
            $n$, _job_number, _field, current_val, _old_val, _new_val);
    END IF;

END
$BODY$ LANGUAGE plpgsql;

/* 
Procedure to apply all corrections of a given field.
If a field does not exist in the table or is a geometry field, notice gets raised.
*/
DROP PROCEDURE IF EXISTS apply_correction;
CREATE OR REPLACE PROCEDURE apply_correction (
    _table text, 
    _corrections text,
    _field text
) AS $BODY$
DECLARE 
    _job_number text;
    _old_value text;
    _new_value text;
    _valid_fields text[];
BEGIN
    SELECT array_agg(column_name) FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = _table INTO  _valid_fields;

    IF _field IN _valid_fields AND _field NOT IN ('latitude','longitude') THEN
        FOR _job_number, _field, _old_value, _new_value IN 
            EXECUTE FORMAT($n$
                SELECT job_number, field, old_value, new_value 
                FROM %1$s
                WHERE field = _field
            $n$, _corrections)
        LOOP
            CALL correction(_table, _job_number, _field, _old_value, _new_value);
        END LOOP;

    ELSE
        RAISE NOTICE '(%1) is not a valid field for function apply_correction to (%2)', _field, _table;    
    END IF;
END
$BODY$ LANGUAGE plpgsql;