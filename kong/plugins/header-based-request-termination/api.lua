local endpoints = require "kong.api.endpoints"

local integration_access_settings_schema = kong.db.integration_access_settings.schema

return {
    ["/integration-access-settings"] = {
        schema = integration_access_settings_schema,
        methods = {
            POST = endpoints.post_collection_endpoint(integration_access_settings_schema),
            GET = endpoints.get_collection_endpoint(integration_access_settings_schema),
        }
    },
    ["/integration-access-settings/:integration_access_settings"] = {
        schema = integration_access_settings_schema,
        methods = {
            before = function(self, db, helpers)

                local access_setting, _, err_t = endpoints.select_entity(self, db, integration_access_settings_schema)

                if err_t then
                    return endpoints.handle_error(err_t)
                end
                if not access_setting then
                    return kong.response.exit(404, { message = "Not found" })
                end
            end,

            DELETE = endpoints.delete_entity_endpoint(integration_access_settings_schema)
        }
    }
}
