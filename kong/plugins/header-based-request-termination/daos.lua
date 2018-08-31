local singletons = require "kong.singletons"

local function check_unique_for_both_identifiers(_, integration_access_settings)
    local access_settings = singletons.dao.integration_access_settings:find_all {
        source_identifier = integration_access_settings.source_identifier,
        target_identifier = integration_access_settings.target_identifier
    }

    if #access_settings > 0 then
        return false, "Integration access setting already exists."
    else
        return true
    end
end

local SCHEMA = {
    primary_key = { "id" },
    table = "integration_access_settings",
    cache_key = { "source_identifier", "target_identifier" },
    fields = {
        id = { type = "id", dao_insert_value = true },
        source_identifier = { type = "string", required = true, func = check_unique_for_both_identifiers },
        target_identifier = { type = "string", required = true }
    }
}

return { integration_access_settings = SCHEMA }
