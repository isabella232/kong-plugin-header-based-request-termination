local Errors = require "kong.dao.errors"

local function check_unique_for_both_identifiers(schema, config, dao, is_update)
    local access_settings = dao:find_all({
        source_identifier = config.source_identifier,
        target_identifier = config.target_identifier
    })

    if #access_settings > 0 then
        return false, Errors.schema("Integration access setting already exists.")
    end

    return true
end

local SCHEMA = {
    primary_key = { "id" },
    table = "integration_access_settings",
    cache_key = { "source_identifier", "target_identifier" },
    fields = {
        id = { type = "id", dao_insert_value = true },
        source_identifier = { type = "string", required = true },
        target_identifier = { type = "string", required = true }
    },
    self_check = check_unique_for_both_identifiers
}

return { integration_access_settings = SCHEMA }
