return {
    {
        name = "2018-08-30-130000_integration_access_settings",
        up = [[
              CREATE TABLE IF NOT EXISTS integration_access_settings(
                id uuid,
                source_identifier text,
                target_identifier text,
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
              ALTER TABLE integration_access_settings ADD darklaunch_mode TYPE boolean;
            ]],
        down = [[
              ALTER TABLE integration_access_settings DROP darklaunch_mode;
            ]]
    },
    {
        name = "2019-02-27-100100_add_darklaunch_mode_defaults",
        up = function(_, _, dao)
            local rows, err = dao.integration_access_settings:find_all()

            if err then
                return err
            end

            for _, row in ipairs(rows) do
                row.darklaunch_mode = false

                local _, err = dao.integration_access_settings:update(row, row)

                if err then
                    return err
                end
            end
        end,
        down = function()
        end
    },
    {
        name = "2019-02-27-151000_remove_darklaunch_mode",
        up = [[
              ALTER TABLE integration_access_settings DROP darklaunch_mode;
            ]],
        down = [[
              ALTER TABLE integration_access_settings ADD darklaunch_mode TYPE boolean;
            ]]
    }
}
