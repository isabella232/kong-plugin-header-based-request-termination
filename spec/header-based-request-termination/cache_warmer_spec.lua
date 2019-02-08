local helpers = require "spec.helpers"
local cjson = require "cjson"
local singletons = require "kong.singletons"

describe("CacheWarmer", function()

    setup(function()
        singletons.dao = helpers.dao
    end)

    before_each(function()
        helpers.db:truncate()
    end)

    after_each(function()
        helpers.stop_kong()
    end)

    context("cache_all_entities", function()

        it("should store integration access setting in cache", function()
            local integration_access_setting = helpers.dao.integration_access_settings:insert({
                source_identifier = "test-integration",
                target_identifier = "1234567890",
            })

            helpers.start_kong({ plugins = "header-based-request-termination" })

            local cache_key = helpers.dao.integration_access_settings:cache_key(integration_access_setting.source_identifier, integration_access_setting.target_identifier)

            local raw_response = assert(helpers.admin_client():send {
                method = "GET",
                path = "/cache/" .. cache_key,
            })

            local body = assert.res_status(200, raw_response)
            local response = cjson.decode(body)

            assert.is_equal(response.source_identifier, "test-integration")
            assert.is_equal(response.target_identifier, "1234567890")
        end)
    end)
end)