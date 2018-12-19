local helpers = require "spec.helpers"
local cjson = require "cjson"
local TestHelper = require "spec.test_helper"

local function get_response_body(response)
    local body = assert.res_status(201, response)
    return cjson.decode(body)
end

local function setup_test_env(config)
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

    after_each(function()
        TestHelper.truncate_tables()
    end)

    describe("Admin API", function()

        before_each(function()
            TestHelper.truncate_tables()
            local default_config = { source_header = "X-Source-Id", target_header = "X-Target-Id" }
            service, route, plugin, consumer = setup_test_env(default_config)
        end)

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

            it("should save access information into the database for a specific customer id", function()
                local post_response = assert(helpers.admin_client():send({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "test-integration",
                        target_identifier = "1234567890",
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
                assert.is_equal(body.data[1].target_identifier, "1234567890")
            end)

        end)

        describe("DELETE access rule", function()
            it("should delete access information from the database when it exists", function()
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

                local setting_raw_response = assert.res_status(201, post_response)
                local setting_id = cjson.decode(setting_raw_response)['id']

                local get_response = assert(helpers.admin_client():send({
                    method = "DELETE",
                    path = "/integration-access-settings/"..setting_id,
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                }))

                assert.res_status(204, get_response)
            end)

            it("should respond with 404 not found when access information does not exist in the database", function()
                local get_response = assert(helpers.admin_client():send({
                    method = "DELETE",
                    path = "/integration-access-settings/14797c66-eabd-4db9-9cd8-5ed4a83aa98d",
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                }))

                assert.res_status(404, get_response)
            end)
        end)

    end)

    describe("Header based request termination", function()

        context("with default config", function()

            before_each(function()
                TestHelper.truncate_tables()
                local default_config = { source_header = "X-Source-Id", target_header = "X-Target-Id" }
                service, route, plugin, consumer = setup_test_env(default_config)
            end)

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

            it("should allow passthrough when source identifier and target identifier are the same", function()
                local response = assert(helpers.proxy_client():send({
                    method = "GET",
                    path = "/test",
                    headers = {
                        ["X-Source-Id"] = "some-customer-name",
                        ["X-Target-Id"] = "some-customer-name",
                    }
                }))

                assert.res_status(200, response)
            end)

            it("should allow request when target identifier is not present on request", function()
                local response = assert(helpers.proxy_client():send({
                    method = "GET",
                    path = "/test",
                    headers = {
                        ["X-Source-Id"] = "test-integration",
                    }
                }))

                assert.res_status(200, response)
            end)

            it("should allow request when source identifier is not present on request", function()
                local response = assert(helpers.proxy_client():send({
                    method = "GET",
                    path = "/test",
                    headers = {
                        ["X-Target-Id"] = "123456789",
                    }
                }))

                assert.res_status(200, response)
            end)

            it("should allow request when target identifier is configured as a wildcard in settings", function()
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

            it("should allow request when target identifier is configured as a specific customer ID in settings", function()
                local post_response = assert(helpers.admin_client():send({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "test-integration",
                        target_identifier = "1234567890",
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
                        ["X-Source-Id"] = "test-integration",
                        ["X-Target-Id"] = "1234567890",
                    }
                }))

                assert.res_status(200, response)
            end)

        end)

        context("with custom reject config", function()

            before_each(function()
                TestHelper.truncate_tables()
            end)

            it("should respond with custom message on rejection when configured accordingly", function()
                local expectedMessage = "So long and thanks for all the fish!"
                setup_test_env({
                    source_header = "X-Source-Id",
                    target_header = "X-Target-Id",
                    message = expectedMessage
                })

                local response = assert(helpers.proxy_client():send({
                    method = "GET",
                    path = "/test",
                    headers = {
                        ["X-Source-Id"] = "test-integration",
                        ["X-Target-Id"] = "123456789",
                    }
                }))

                local body = response:read_body()
                local json = cjson.decode(body)
                assert.same({ message = expectedMessage }, json)
            end)

            it("should respond with custom status code on rejection when configured accordingly", function()
                local expectedStatusCode = 503
                setup_test_env({
                    source_header = "X-Source-Id",
                    target_header = "X-Target-Id",
                    status_code = expectedStatusCode
                })

                local response = assert(helpers.proxy_client():send({
                    method = "GET",
                    path = "/test",
                    headers = {
                        ["X-Source-Id"] = "test-integration",
                        ["X-Target-Id"] = "123456789",
                    }
                }))

                assert.res_status(expectedStatusCode, response)
            end)

        end)

        context("with log only config", function()

            before_each(function()
                TestHelper.truncate_tables()
            end)

            it("should not reject request if log only mode enabled", function()
                setup_test_env({
                    source_header = "X-Source-Id",
                    target_header = "X-Target-Id",
                    log_only = true
                })

                local response = assert(helpers.proxy_client():send({
                    method = "GET",
                    path = "/test",
                    headers = {
                        ["X-Source-Id"] = "test-integration",
                        ["X-Target-Id"] = "123456789",
                    }
                }))

                assert.res_status(200, response)
            end)

        end)

        context("with caching", function()

            before_each(function()
                TestHelper.truncate_tables()
            end)

            it("should not reject request if db is down", function()
                setup_test_env({
                    source_header = "X-Source-Id",
                    target_header = "X-Target-Id",
                })

                local setting_response = assert(helpers.admin_client():send({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "test-integration1",
                        target_identifier = "*",
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                }))

                assert.res_status(201, setting_response)

                local response = assert(helpers.proxy_client():send({
                    method = "GET",
                    path = "/test",
                    headers = {
                        ["X-Source-Id"] = "test-integration1",
                        ["X-Target-Id"] = "123456789",
                    }
                }))

                assert.res_status(200, response)

                local dao = select(3, helpers.get_db_utils())
                pcall(dao.truncate, dao)

                local response = assert(helpers.proxy_client():send({
                    method = "GET",
                    path = "/test",
                    headers = {
                        ["X-Source-Id"] = "test-integration1",
                        ["X-Target-Id"] = "123456789",
                    }
                }))

                assert.res_status(200, response)
            end)

        end)

    end)
end)
