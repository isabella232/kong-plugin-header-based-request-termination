local Errors = require "kong.db.errors"

local function check_unique_for_both_identifiers(source_identifier, target_identifier)

    local access_settings = kong.db.integration_access_settings:select_by_cache_key({ source_identifier, target_identifier })

    if not access_settings then
        return true
    end
    if #access_settings > 0 then
        return false, Errors.schema("Integration access setting already exists.")
    end

    return true
end

local typedefs = require "kong.db.schema.typedefs"

return { integration_access_settings = {
    name = "integration_access_settings",
    primary_key = { "id" },
    cache_key = { "source_identifier", "target_identifier" },
    generate_admin_api = false,
    endpoint_key = "id",
    fields = {
        { id = typedefs.uuid },
        { source_identifier = { type = "string", required = true } },
        { target_identifier = { type = "string", required = true } }
    },
    entity_checks = {
        { custom_entity_check = {
            field_sources = { "source_identifier", "target_identifier" },
            fn = function(entity)
                if entity.source_identifier ~= ngx.null and entity.target_identifier ~= ngx.null then
                    local valid, error_message = check_unique_for_both_identifiers(entity.source_identifier, entity.target_identifier)
                    if not valid then
                        return false, error_message
                    end
                    return true
                end

            end
        } }
    }
} }