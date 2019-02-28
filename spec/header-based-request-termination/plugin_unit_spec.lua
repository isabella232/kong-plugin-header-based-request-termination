local PluginHandler = require "kong.plugins.header-based-request-termination.handler"
local Access = require "kong.plugins.header-based-request-termination.access"

local old_ngx

local function mock_ngx()
    old_ngx = _G.ngx

    local ngx = {
        ERR = "ERROR:",
        header = {},
        ctx = {},
        var = {},
        log = function() end,
        say = function() end,
        exit = function() end
    }

    _G.ngx = ngx
end

local function restore_mocked_ngx()
    _G.ngx = old_ngx
end

local old_kong

local function mock_kong()
    old_kong = _G.kong

    local kong = {
        response = {
            exit = function() end
        }
    }

    mock(kong, true)

    _G.kong = kong
end

local function restore_mocked_kong()
    _G.kong = old_kong
end

describe("header-based-request-termination plugin", function()
    local plugin_handler

    before_each(function()
        mock_ngx()
        mock_kong()

        plugin_handler = PluginHandler()
    end)

    after_each(function()
        restore_mocked_ngx()
        restore_mocked_kong()
    end)

    it("should block request on internal server error", function()
        local old_access_execute = Access.execute

        Access.execute = function()
            error("DB is down")
        end

        plugin_handler:access()

        Access.execute = old_access_execute

        assert.stub(kong.response.exit).was.called_with(500, { message = "An unexpected error occurred" })
    end)

end)
