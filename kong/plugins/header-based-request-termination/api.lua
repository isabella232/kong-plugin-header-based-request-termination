local crud = require "kong.api.crud_helpers"

local unescape_uri = ngx.unescape_uri

return {
    ["/integration-access-settings"] = {
        POST = function(self, dao_factory, helpers)
            crud.post(self.params, dao_factory.integration_access_settings)
        end,

        GET = function(self, dao_factory, helpers)
            crud.paginated_set(self, dao_factory.integration_access_settings)
        end
    },
    ["/integration-access-settings/:setting_id"] = {
        before = function(self, dao_factory, helpers)
            local settings, err = crud.find_by_id_or_field(
                dao_factory.integration_access_settings,
                nil,
                unescape_uri(self.params.setting_id),
                "id"
            )

            if err then
                return helpers.yield_error(err)
            elseif next(settings) == nil then
                return helpers.responses.send_HTTP_NOT_FOUND()
            end

            self.params.setting_id = nil

            self.setting = settings[1]
        end,

        DELETE = function(self, dao_factory, helpers)
            crud.delete(self.setting, dao_factory.integration_access_settings)
        end
    }
}
