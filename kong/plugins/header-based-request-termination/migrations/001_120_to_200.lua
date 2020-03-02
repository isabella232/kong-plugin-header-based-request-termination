return {
    postgres = {
        up = [[
            DO $$
            BEGIN
            ALTER TABLE IF EXISTS ONLY "integration_access_settings" ADD "cache_key" TEXT UNIQUE;
            EXCEPTION WHEN DUPLICATE_COLUMN THEN
            -- Do nothing, accept existing state
            END;
            $$;
        ]]
    },
    cassandra = {
        up = [[
            ALTER TABLE integration_access_settings ADD cache_key text;
            CREATE INDEX IF NOT EXISTS ON integration_access_settings (cache_key);
        ]]
    }
}