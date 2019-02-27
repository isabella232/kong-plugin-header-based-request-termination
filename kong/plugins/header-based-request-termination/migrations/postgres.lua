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
    },
    {
        name = "2019-02-27-100000_add_darklaunch_mode",
        up = [[
              ALTER TABLE integration_access_settings ADD COLUMN darklaunch_mode boolean DEFAULT FALSE;
            ]],
        down = [[
              ALTER TABLE integration_access_settings DROP COLUMN darklaunch_mode;
            ]]
    },
    {
        name = "2019-02-27-151000_remove_darklaunch_mode",
        up = [[
               ALTER TABLE integration_access_settings DROP COLUMN darklaunch_mode;
            ]],
        down = [[
               ALTER TABLE integration_access_settings ADD COLUMN darklaunch_mode boolean DEFAULT FALSE;
            ]]
    }
}
