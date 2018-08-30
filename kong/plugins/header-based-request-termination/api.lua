local crud = require "kong.api.crud_helpers"

return {
    ['/integration-access-settings'] = {
        POST = function(self, dao_factory, helpers)
            crud.post(self.params, dao_factory.integration_access_settings)
        end,

        GET = function(self, dao_factory, helpers)
            crud.paginated_set(self, dao_factory.integration_access_settings)
        end
    }
}
