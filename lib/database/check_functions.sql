-- Functions to check database structure and validate setup

-- Create function to check if PostGIS is installed
CREATE OR REPLACE FUNCTION check_postgis_exists()
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'postgis'
    );
END;
$$;

-- Create function to check if markets.gps_location column exists
CREATE OR REPLACE FUNCTION check_markets_gps_column()
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'markets' 
        AND column_name = 'gps_location'
    );
END;
$$;

-- Bundle function creation to create these utility functions
CREATE OR REPLACE FUNCTION create_database_check_functions()
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
    -- Create check_postgis_exists function
    EXECUTE $FUNC$
    CREATE OR REPLACE FUNCTION check_postgis_exists()
    RETURNS boolean
    LANGUAGE plpgsql
    AS $F$
    BEGIN
        RETURN EXISTS (
            SELECT 1 FROM pg_extension WHERE extname = 'postgis'
        );
    END;
    $F$;
    $FUNC$;

    -- Create check_markets_gps_column function
    EXECUTE $FUNC$
    CREATE OR REPLACE FUNCTION check_markets_gps_column()
    RETURNS boolean
    LANGUAGE plpgsql
    AS $F$
    BEGIN
        RETURN EXISTS (
            SELECT 1 
            FROM information_schema.columns 
            WHERE table_name = 'markets' 
            AND column_name = 'gps_location'
        );
    END;
    $F$;
    $FUNC$;

    -- Create function to check for required tables
    EXECUTE $FUNC$
    CREATE OR REPLACE FUNCTION check_required_tables()
    RETURNS TABLE (table_name text, exists boolean)
    LANGUAGE plpgsql
    AS $F$
    BEGIN
        RETURN QUERY
        SELECT t.table_name::text, 
               EXISTS (
                   SELECT 1 
                   FROM information_schema.tables 
                   WHERE table_name = t.table_name
               ) as exists
        FROM (VALUES 
            ('regions'), 
            ('vendors'), 
            ('markets'), 
            ('products'), 
            ('promotions'), 
            ('sales')
        ) AS t(table_name);
    END;
    $F$;
    $FUNC$;
    
    RETURN true;
END;
$$; 