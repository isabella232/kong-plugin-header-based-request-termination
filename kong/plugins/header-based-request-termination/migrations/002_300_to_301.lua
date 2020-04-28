return {
    postgres = {
        up = [[
            DO $$
            BEGIN
            UPDATE integration_access_settings SET cache_key = CONCAT('integration_access_settings', ':', source_identifier, ':', target_identifier, ':::') WHERE cache_key is null;
            END;
            $$;
        ]]
    },
    cassandra = {
        up = [[
            UPDATE integration_access_settings SET cache_key = CONCAT('integration_access_settings', ':', source_identifier, ':', target_identifier, ':::') WHERE cache_key is null;
        ]]
    }
}