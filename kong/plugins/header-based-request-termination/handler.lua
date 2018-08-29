local BasePlugin = require "kong.plugins.base_plugin"

local HeaderBasedRequestTerminationHandler = BasePlugin:extend()

HeaderBasedRequestTerminationHandler.PRIORITY = 902

function HeaderBasedRequestTerminationHandler:new()
  HeaderBasedRequestTerminationHandler.super.new(self, "header-based-request-termination")
end

function HeaderBasedRequestTerminationHandler:access(conf)
  HeaderBasedRequestTerminationHandler.super.access(self)
end

return HeaderBasedRequestTerminationHandler
