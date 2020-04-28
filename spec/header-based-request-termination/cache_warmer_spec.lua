local helpers = require "spec.helpers"
local test_helpers = require "kong_client.spec.test_helpers"

describe("CacheWarmer", function()

    local consumer
    local db

    setup(function()
        local _
        _, db = helpers.get_db_utils()
    end)

    before_each(function()
        db:truncate()
        consumer = db.consumers:insert({
            username = "CacheTestUser"
        })
    end)

    after_each(function()
        helpers.stop_kong()
    end)

    context("cache_all_entities", function()

        it("should store integration access setting in cache", function()

            local integration_access_setting = db.integration_access_settings:insert({
                source_identifier = "test-integration",
                target_identifier = "1234567890"
            })

            helpers.start_kong({ plugins = "header-based-request-termination" })

            local cache_key = db.integration_access_settings:cache_key(integration_access_setting.source_identifier, integration_access_setting.target_identifier)

            local send_admin_request = test_helpers.create_request_sender(helpers.admin_client())
            local response = send_admin_request({
                method = "GET",
                path = "/cache/" .. cache_key
            })

            assert.is_equal("test-integration", response.body.source_identifier)
            assert.is_equal("1234567890", response.body.target_identifier)
        end)
    end)
end)