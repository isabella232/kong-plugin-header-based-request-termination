local BasePlugin = require "kong.plugins.base_plugin"
local InitWorker = require "kong.plugins.header-based-request-termination.init_worker"
local Logger = require "logger"

local Access = require "kong.plugins.header-based-request-termination.access"

local HeaderBasedRequestTerminationHandler = BasePlugin:extend()

HeaderBasedRequestTerminationHandler.PRIORITY = 902

function HeaderBasedRequestTerminationHandler:new()
    HeaderBasedRequestTerminationHandler.super.new(self, "header-based-request-termination")
end

function HeaderBasedRequestTerminationHandler:init_worker()
    HeaderBasedRequestTerminationHandler.super.init_worker(self)

    InitWorker.execute()
end

function HeaderBasedRequestTerminationHandler:access(conf)
    HeaderBasedRequestTerminationHandler.super.access(self)

    local success, error = pcall(Access.execute, conf)

    if not success then
        Logger.getInstance(ngx):logError(error)
    end
end

return HeaderBasedRequestTerminationHandler
