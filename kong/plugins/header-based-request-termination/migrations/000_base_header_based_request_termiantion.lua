return {
    postgres = {
        up = [[
              CREATE TABLE IF NOT EXISTS integration_access_settings(
                id uuid,
                source_identifier text NOT NULL,
                target_identifier text NOT NULL,
                PRIMARY KEY (id)
              );
            ]],
    },
    cassandra = {
        up = [[
              CREATE TABLE IF NOT EXISTS integration_access_settings(
                id uuid,
                source_identifier text,
                target_identifier text,
                PRIMARY KEY (id)
              );
            ]],
    },
}