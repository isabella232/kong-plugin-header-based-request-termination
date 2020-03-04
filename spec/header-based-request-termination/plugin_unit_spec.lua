require "spec.helpers"

describe("header-based-request-termination plugin", function()

   local PluginHandler, Access

   setup(function()
        PluginHandler = require "kong.plugins.header-based-request-termination.handler"
        Access = require "kong.plugins.header-based-request-termination.access"
   end)

   local plugin_handler

   before_each(function()
        plugin_handler = PluginHandler()

        mock(kong, true)
   end)

   after_each(function()
        mock.revert(kong)
   end)

   it("should block request on internal server error", function()
        local Logger = require "logger"
        local old_logger = Logger.getInstance
        Logger.getInstance = function() return { logError = function() end } end
        local old_access_execute = Access.execute

        Access.execute = function()
            error("DB is down")
        end

        plugin_handler:access()

        Access.execute = old_access_execute
        Logger.getInstance = old_logger

        assert.stub(kong.response.exit).was.called_with(500, { message = "An unexpected error occurred" })
   end)

end)
