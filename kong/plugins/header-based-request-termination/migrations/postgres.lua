return {
    {
        name = "2018-08-30-130000_integration_access_settings",
        up = [[
              CREATE TABLE IF NOT EXISTS integration_access_settings(
                id uuid,
                source_identifier text NOT NULL,
                target_identifier text NOT NULL,
                PRIMARY KEY (id)
              );
            ]],
        down = [[
              DROP TABLE integration_access_settings;
            ]]
    }
}
