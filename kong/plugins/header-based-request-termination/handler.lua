local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"
local BasePlugin = require "kong.plugins.base_plugin"
local Logger = require "logger"

local function log_termination(query)
    Logger.getInstance(ngx):logInfo({
        ["msg"] = "Request terminated based on headers",
        ["uri"] = ngx.var.request_uri,
        ["source_identifier"] = query.source_identifier,
        ["target_identifier"] = query.target_identifier
    })
end

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

    local query = { source_identifier = source_header_value, target_identifier = '*' }
    local access_settings = singletons.dao.integration_access_settings:find_all(query)

    if #access_settings == 0 then
        if conf.log_only then
            log_termination(query)
            return
        end
        responses.send(conf.status_code, conf.message)
    end

end

return HeaderBasedRequestTerminationHandler
