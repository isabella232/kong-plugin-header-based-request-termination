local helpers = require "spec.helpers"
local cjson = require "cjson"
local TestHelper = require "spec.test_helper"
local test_helpers = require "kong_client.spec.test_helpers"

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
        helpers.start_kong({ plugins = "header-based-request-termination" })
    end)

    teardown(function()
        helpers.stop_kong()
    end)

    local service, route, plugin, consumer

    before_each(function()
        helpers.db:truncate()
    end)

    after_each(function()
        helpers.db:truncate()
    end)

    describe("Config", function()

        local kong_sdk, send_request, send_admin_request

        before_each(function()
            kong_sdk = test_helpers.create_kong_client()
            send_request = test_helpers.create_request_sender(helpers.proxy_client())
            send_admin_request = test_helpers.create_request_sender(helpers.admin_client())
        end)

        context("when config parameter is not given", function()

            before_each(function()
                service = kong_sdk.services:create({
                    name = "EchoService",
                    url = "http://mockbin:8080/request"
                })

                kong_sdk.routes:create_for_service(service.id, "/echo")
            end)

            it("should set default config values", function()
                local plugin_response = kong_sdk.plugins:create({
                    service_id = service.id,
                    name = "header-based-request-termination",
                    config = {
                        source_header = 'X-Source-Header',
                        target_header = 'X-Target-Header'
                    }
                })
                local config = plugin_response.config

                assert.is_equal(config.status_code, 403)
                assert.is_equal(config.log_only, false)
                assert.is_equal(config.darklaunch_mode, false)
                assert.is_equal(config.message, '{"message": "Forbidden"}')
            end)

            local test_cases = {"Hello bye!", '""', '[{"message": "value"}]'}

            for _, test_message in ipairs(test_cases) do
                it("should throw error when message is not valid JSON object", function()
                    local success, response = pcall(function()
                        return kong_sdk.plugins:create({
                            service_id = service.id,
                            name = "header-based-request-termination",
                            config = {
                                source_header = 'X-Source-Header',
                                target_header = 'X-Target-Header',
                                message = test_message
                            }
                        })
                    end)

                    assert.is_equal(response.status, 400)
                    assert.is_equal(response.body["config.message"], "message should be valid JSON object")
                end)
            end
        end)

    end)

    describe("Admin API", function()

        before_each(function()
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
                path = "/plugins/" .. plugin.id,
            })
            assert.res_status(200, res)
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
                local setting_id = cjson.decode(setting_raw_response)["id"]

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

            it("should block request when source identifier is not present on request", function()
                local response = assert(helpers.proxy_client():send({
                    method = "GET",
                    path = "/test",
                }))

                assert.res_status(403, response)

                local body = response:read_body()
                local json = cjson.decode(body)

                assert.is_equal(json.message, 'Forbidden')
                assert.is_equal(response.headers['Content-Type'], 'application/json; charset=utf-8')
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

            it("should respond with custom message on rejection when configured accordingly", function()
                setup_test_env({
                    source_header = "X-Source-Id",
                    target_header = "X-Target-Id",
                    message = '{"message":"So long and thanks for all the fish!"}'
                })

                local response = assert(helpers.proxy_client():send({
                    method = "GET",
                    path = "/test",
                    headers = {
                        ["X-Source-Id"] = "test-integration",
                        ["X-Target-Id"] = "123456789",
                    }
                }))

                assert.res_status(403, response)

                local body = response:read_body()
                local json = cjson.decode(body)
                assert.same({ message = "So long and thanks for all the fish!" }, json)
                assert.is_equal(response.headers['Content-Type'], 'application/json; charset=utf-8')

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

        context("with log only enabled", function()

            it("should not reject request when settings cannot be found", function()
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

            it("should not reject request when source header is missing", function()
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

            context("with darklaunch mode enabled", function()

                it("should add block decision as header", function()
                    setup_test_env({
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id",
                        log_only = true,
                        darklaunch_mode = true
                    })

                    local response = assert(helpers.proxy_client():send({
                        method = "GET",
                        path = "/test",
                        headers = {
                            ["X-Source-Id"] = "test-integration",
                            ["X-Target-Id"] = "darklaunch-blocked-customer"
                        }
                    }))

                    local body = assert.res_status(200, response)
                    local parsed_body = cjson.decode(body)

                    assert.is_equal("block", parsed_body.headers["x-request-termination-decision"])
                end)

                it("should add allow decision as header when every customer has access", function()
                    setup_test_env({
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id",
                        log_only = true,
                        darklaunch_mode = true
                    })

                    local setting_response = assert(helpers.admin_client():send({
                        method = "POST",
                        path = "/integration-access-settings",
                        body = {
                            source_identifier = "darklaunch-allow-every",
                            target_identifier = "*"
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
                            ["X-Source-Id"] = "darklaunch-allow-every",
                            ["X-Target-Id"] = "123456789"
                        }
                    }))

                    local body = assert.res_status(200, response)
                    local parsed_body = cjson.decode(body)

                    assert.is_equal("allow", parsed_body.headers["x-request-termination-decision"])
                end)

                it("should add allow decision as header when specific customer has access", function()
                    setup_test_env({
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id",
                        log_only = true,
                        darklaunch_mode = true
                    })

                    local setting_response = assert(helpers.admin_client():send({
                        method = "POST",
                        path = "/integration-access-settings",
                        body = {
                            source_identifier = "test-integration",
                            target_identifier = "darklaunch-allow-customer"
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
                            ["X-Source-Id"] = "test-integration",
                            ["X-Target-Id"] = "darklaunch-allow-customer"
                        }
                    }))

                    local body = assert.res_status(200, response)
                    local parsed_body = cjson.decode(body)

                    assert.is_equal("allow", parsed_body.headers["x-request-termination-decision"])
                end)

            end)

            context("with darklaunch mode disabled", function()

                it("should not add decision as header", function()
                    setup_test_env({
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id",
                        log_only = true,
                        darklaunch_mode = false
                    })

                    local response = assert(helpers.proxy_client():send({
                        method = "GET",
                        path = "/test",
                        headers = {
                            ["X-Source-Id"] = "test-integration",
                            ["X-Target-Id"] = "darklaunch-blocked-customer"
                        }
                    }))

                    local body = assert.res_status(200, response)
                    local parsed_body = cjson.decode(body)

                    assert.is_nil(parsed_body.headers["x-request-termination-decision"])
                end)

                it("should not add allow decision as header when every customer has access", function()
                    setup_test_env({
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id",
                        log_only = true,
                        darklaunch_mode = false
                    })

                    local setting_response = assert(helpers.admin_client():send({
                        method = "POST",
                        path = "/integration-access-settings",
                        body = {
                            source_identifier = "darklaunch-allow-every",
                            target_identifier = "*"
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
                            ["X-Source-Id"] = "darklaunch-allow-every",
                            ["X-Target-Id"] = "123456789"
                        }
                    }))

                    local body = assert.res_status(200, response)
                    local parsed_body = cjson.decode(body)

                    assert.is_nil(parsed_body.headers["x-request-termination-decision"])
                end)

                it("should add allow decision as header when specific customer has access", function()
                    setup_test_env({
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id",
                        log_only = true,
                        darklaunch_mode = false
                    })

                    local setting_response = assert(helpers.admin_client():send({
                        method = "POST",
                        path = "/integration-access-settings",
                        body = {
                            source_identifier = "test-integration",
                            target_identifier = "darklaunch-allow-customer"
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
                            ["X-Source-Id"] = "test-integration",
                            ["X-Target-Id"] = "darklaunch-allow-customer"
                        }
                    }))

                    local body = assert.res_status(200, response)
                    local parsed_body = cjson.decode(body)

                    assert.is_nil(parsed_body.headers["x-request-termination-decision"])
                end)

            end)

        end)

        context("with log only disabled and darklaunch enabled", function()

            it("should not add block decision as header", function()
                setup_test_env({
                    source_header = "X-Source-Id",
                    target_header = "X-Target-Id",
                    log_only = false,
                    darklaunch_mode = true
                })

                local setting_response = assert(helpers.admin_client():send({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "darklaunch-without-log-only",
                        target_identifier = "darklaunch-allow-customer"
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
                        ["X-Source-Id"] = "darklaunch-without-log-only",
                        ["X-Target-Id"] = "darklaunch-allow-customer"
                    }
                }))

                local body = response:read_body()
                local parsed_body = cjson.decode(body)

                assert.is_nil(parsed_body.headers["x-request-termination-decision"])
            end)

        end)

        context("with caching", function()

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
