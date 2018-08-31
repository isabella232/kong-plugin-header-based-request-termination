local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"
local BasePlugin = require "kong.plugins.base_plugin"

local HeaderBasedRequestTerminationHandler = BasePlugin:extend()

HeaderBasedRequestTerminationHandler.PRIORITY = 902

function HeaderBasedRequestTerminationHandler:new()
    HeaderBasedRequestTerminationHandler.super.new(self, "header-based-request-termination")
end

function HeaderBasedRequestTerminationHandler:access(conf)
    HeaderBasedRequestTerminationHandler.super.access(self)

    local headers = ngx.req.get_headers()
    local source_header_value = headers[conf.source_header]
    local target_header_value = headers[conf.target_header]

    if not target_header_value then
        return
    end

    local access_settings = singletons.dao.integration_access_settings:find_all({ source_identifier = source_header_value, target_identifier = '*' })

    if #access_settings == 0 then
        return responses.send(403, conf.message)
    end

end

return HeaderBasedRequestTerminationHandler
