local helpers = require "spec.helpers"
local test_helpers = require "kong_client.spec.test_helpers"

local function send_admin_request(request)
    local request_sender = test_helpers.create_request_sender(helpers.admin_client())
    return request_sender(request)
end

describe("CacheWarmer", function()

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
                target_identifier = "1234567890"
            })

            helpers.start_kong({ plugins = "header-based-request-termination" })

            local cache_key = helpers.dao.integration_access_settings:cache_key(integration_access_setting.source_identifier, integration_access_setting.target_identifier)

            local response = send_admin_request({
                method = "GET",
                path = "/cache/" .. cache_key
            })

            assert.is_equal("test-integration", response.body.source_identifier)
            assert.is_equal("1234567890", response.body.target_identifier)
        end)
    end)
end)