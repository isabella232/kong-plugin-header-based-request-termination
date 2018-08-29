local BasePlugin = require "kong.plugins.base_plugin"

local HeaderBasedRequestTerminationHandler = BasePlugin:extend()

HeaderBasedRequestTerminationHandler.PRIORITY = 902

function HeaderBasedRequestTerminationHandler:new()
  HeaderBasedRequestTerminationHandler.super.new(self, "header-based-request-termination")
end

function HeaderBasedRequestTerminationHandler:access(conf)
  HeaderBasedRequestTerminationHandler.super.access(self)

  if conf.say_hello then
    ngx.log(ngx.ERR, "============ Hey World! ============")
    ngx.header["Hello-World"] = "Hey!"
  else
    ngx.log(ngx.ERR, "============ Bye World! ============")
    ngx.header["Hello-World"] = "Bye!"
  end

end

return HeaderBasedRequestTerminationHandler
