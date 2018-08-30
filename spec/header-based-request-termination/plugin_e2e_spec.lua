local helpers = require "spec.helpers"
local cjson = require "cjson"
local TestHelper = require "spec.test_helper"

local function get_response_body(response)
    local body = assert.res_status(201, response)
    return cjson.decode(body)
end

local function setup_test_env()
    local config = { source_header = "X-Source-Id", target_header = "X-Target-Id" }
    local service = get_response_body(TestHelper.setup_service())
    local route = get_response_body(TestHelper.setup_route_for_service(service.id))
    local plugin = get_response_body(TestHelper.setup_plugin_for_service(service.id, "header-based-request-termination", config))
    local consumer = get_response_body(TestHelper.setup_consumer("TestUser"))
    return service, route, plugin, consumer
end

describe("Plugin: header-based-request-termination (access)", function()

    setup(function()
        helpers.start_kong({ custom_plugins = 'header-based-request-termination' })
    end)

    teardown(function()
        helpers.stop_kong(nil)
    end)

    local service, route, plugin, consumer

    before_each(function()
        TestHelper.truncate_tables()
        service, route, plugin, consumer = setup_test_env()
    end)

    after_each(function()
        TestHelper.truncate_tables()
    end)

    describe("Admin API", function()

        it("registered the plugin globally", function()
            local res = assert(helpers.admin_client():send {
                method = "GET",
                path = "/plugins/" .. plugin.id,
            })
            local body = assert.res_status(200, res)
            local json = cjson.decode(body)

            assert.is_table(json)
            assert.is_not.falsy(json.enabled)
        end)

        it("registered the plugin for the api", function()
            local res = assert(helpers.admin_client():send {
                method = "GET",
                path = "/plugins/" ..plugin.id,
            })
            local body = assert.res_status(200, res)
            local json = cjson.decode(body)
            assert.is_equal(api_id, json.api_id)
        end)

        describe("POST access rule", function()

            it("should save access information into the database", function()
                local post_response = assert(helpers.admin_client():send({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "test-integration",
                        target_identifier = "*",
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                }))

                assert.res_status(201, post_response)

                local get_response = assert(helpers.admin_client():send({
                    method = "GET",
                    path = "/integration-access-settings",
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                }))

                local raw_response_body = assert.res_status(200, get_response)
                local body = cjson.decode(raw_response_body)

                assert.is_equal(body.data[1].source_identifier, "test-integration")
                assert.is_equal(body.data[1].target_identifier, "*")
            end)

            it("should not enable to save access settings without identifiers", function()
                local post_response = assert(helpers.admin_client():send({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {},
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                }))

                assert.res_status(400, post_response)
            end)

            it("should not enable to save the same access setting", function()
                local requestSettings = {
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "test-integration",
                        target_identifier = "*",
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                }

                local post_response = assert(helpers.admin_client():send(requestSettings))
                assert.res_status(201, post_response)

                local post_response = assert(helpers.admin_client():send(requestSettings))
                assert.res_status(400, post_response)
            end)

        end)

    end)

    describe("Header based request termination", function()

        it("should reject request when source identifier and target identifier combination is not stored", function()
            local response = assert(helpers.proxy_client():send({
                method = "GET",
                path = "/test",
                headers = {
                    ["X-Source-Id"] = "test-integration",
                    ["X-Target-Id"] = "123456789",
                }
            }))

            assert.res_status(403, response)
        end)

        it("should not reject request when target identifier is not present on request", function()
            local response = assert(helpers.proxy_client():send({
                method = "GET",
                path = "/test",
                headers = {
                    ["X-Source-Id"] = "test-integration",
                }
            }))

            assert.res_status(200, response)
        end)

        it("should not reject request when source identifier is not stored", function()
            local post_response = assert(helpers.admin_client():send({
                method = "POST",
                path = "/integration-access-settings",
                body = {
                    source_identifier = "other-test-integration",
                    target_identifier = "*",
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            }))

            assert.res_status(201, post_response)

            local response = assert(helpers.proxy_client():send({
                method = "GET",
                path = "/test",
                headers = {
                    ["X-Source-Id"] = "other-test-integration",
                    ["X-Target-Id"] = "123456789",
                }
            }))

            assert.res_status(200, response)
        end)

    end)
end)
