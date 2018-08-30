
local SCHEMA = {
    primary_key = { "id" },
    table = "integration_access_settings",
    fields = {
        id = { type = "id", dao_insert_value = true },
        source_identifier = { type = "string", required = true },
        target_identifier = { type = "string", required = true }
    }
}

return { integration_access_settings = SCHEMA }
