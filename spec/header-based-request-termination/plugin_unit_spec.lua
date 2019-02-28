local old_ngx

local function fake_ngx()
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

local function restore_faked_ngx()
    _G.ngx = old_ngx
end

local old_kong

local function fake_kong()
    old_kong = _G.kong

    local kong = {
        response = {
            exit = function() end
        }
    }

    _G.kong = kong
end

local function restore_faked_kong()
    _G.kong = old_kong
end

describe("header-based-request-termination plugin", function()

    local PluginHandler, Access

    setup(function()
        fake_ngx()
        fake_kong()

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

    teardown(function()
        restore_faked_ngx()
        restore_faked_kong()
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
