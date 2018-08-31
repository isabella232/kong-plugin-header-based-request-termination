local BasePlugin = require "kong.plugins.base_plugin"
local Logger = require "logger"

local Access = require "kong.plugins.header-based-request-termination.access"

local HeaderBasedRequestTerminationHandler = BasePlugin:extend()

HeaderBasedRequestTerminationHandler.PRIORITY = 902

function HeaderBasedRequestTerminationHandler:new()
    HeaderBasedRequestTerminationHandler.super.new(self, "header-based-request-termination")
end

function HeaderBasedRequestTerminationHandler:access(conf)
    HeaderBasedRequestTerminationHandler.super.access(self)

    local success, error = pcall(Access.execute, conf)

    if not success then
        Logger.getInstance(ngx):logError(error)
    end

end

return HeaderBasedRequestTerminationHandler
