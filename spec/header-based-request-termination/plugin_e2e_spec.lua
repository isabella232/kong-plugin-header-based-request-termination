local helpers = require "spec.helpers"
local test_helpers = require "kong_client.spec.test_helpers"

describe("Plugin: header-based-request-termination (access)", function()

    local kong_sdk, send_request, send_admin_request

    setup(function()
        helpers.start_kong({ plugins = "header-based-request-termination" })
        kong_sdk = test_helpers.create_kong_client()
        send_request = test_helpers.create_request_sender(helpers.proxy_client())
        send_admin_request = test_helpers.create_request_sender(helpers.admin_client())
    end)

    teardown(function()
        helpers.stop_kong()
    end)

    local service

    before_each(function()
        helpers.db:truncate()

        service = kong_sdk.services:create({
            name = "EchoService",
            url = "http://mockbin:8080/request"
        })

        kong_sdk.routes:create_for_service(service.id, "/echo")
    end)

    after_each(function()
        helpers.db:truncate()
    end)

    describe("Config", function()

        context("when config parameter is not given", function()

            it("should set default config values", function()

                local plugin_response = kong_sdk.plugins:create({
                    service_id = service.id,
                    name = "header-based-request-termination",
                    config = {
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id"
                    }
                })

                local config = plugin_response.config

                assert.is_equal(403, config.status_code)
                assert.is_false(config.log_only)
                assert.is_false(config.darklaunch_mode)
                assert.is_equal('{"message": "Forbidden"}', config.message)
            end)

            local test_cases = { "Hello bye!", '""', '[{"message": "value"}]' }

            for _, test_message in ipairs(test_cases) do
                it("should throw error when message is not valid JSON object", function()

                    local success, response = pcall(function()
                        return kong_sdk.plugins:create({
                            service_id = service.id,
                            name = "header-based-request-termination",
                            config = {
                                source_header = "X-Source-Id",
                                target_header = "X-Target-Id",
                                message = test_message
                            }
                        })
                    end)

                    assert.is_equal(400, response.status)
                    assert.is_equal("message should be valid JSON object", response.body["config.message"])
                end)
            end
        end)

    end)

    describe("Admin API", function()

        before_each(function()
            kong_sdk.plugins:create({
                service_id = service.id,
                name = "header-based-request-termination",
                config = {
                    source_header = "X-Source-Id",
                    target_header = "X-Target-Id"
                }
            })
        end)

        describe("POST access rule", function()

            it("should save access information into the database", function()

                send_admin_request({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "test-integration",
                        target_identifier = "*"
                    }
                })

                local response = send_admin_request({
                    method = "GET",
                    path = "/integration-access-settings"
                })

                local access_rule = response.body.data[1]

                assert.is_equal("test-integration", access_rule.source_identifier)
                assert.is_equal("*", access_rule.target_identifier)
            end)

            it("should not enable to save access settings without identifiers", function()

                local success, response = pcall(function()
                    return send_admin_request({
                        method = "POST",
                        path = "/integration-access-settings",
                        body = {}
                    })
                end)

                assert.is_equal(400, response.status)
            end)

            it("should not enable to save the same access setting", function()

                local requestSettings = {
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "test-integration",
                        target_identifier = "*"
                    }
                }

                send_admin_request(requestSettings)

                local success, response = pcall(function()
                    return send_admin_request(requestSettings)
                end)

                assert.is_equal(400, response.status)
            end)

            it("should save access information into the database for a specific customer id", function()

                send_admin_request({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "test-integration",
                        target_identifier = "1234567890"
                    }
                })

                local response = send_admin_request({
                    method = "GET",
                    path = "/integration-access-settings"
                })

                local access_rule = response.body.data[1]

                assert.is_equal("test-integration", access_rule.source_identifier)
                assert.is_equal("1234567890", access_rule.target_identifier)
            end)

        end)

        describe("DELETE access rule", function()
            it("should delete access information from the database when it exists", function()

                local response = send_admin_request({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "test-integration",
                        target_identifier = "*"
                    }
                })

                local delete_response = send_admin_request({
                    method = "DELETE",
                    path = "/integration-access-settings/" .. response.body.id
                })

                assert.is_equal(204, delete_response.status)
            end)

            it("should respond with 404 not found when access information does not exist in the database", function()

                local delete_response = send_admin_request({
                    method = "DELETE",
                    path = "/integration-access-settings/14797c66-eabd-4db9-9cd8-5ed4a83aa98d",
                })

                assert.is_equal(404, delete_response.status)
            end)
        end)

    end)

    describe("Header based request termination", function()

        context("with default config", function()

            before_each(function()
                kong_sdk.plugins:create({
                    service_id = service.id,
                    name = "header-based-request-termination",
                    config = {
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id"
                    }
                })
            end)

            it("should reject request when source identifier and target identifier combination is not stored", function()

                local success, response = pcall(function()
                    return send_request({
                        method = "GET",
                        path = "/echo",
                        headers = {
                            ["X-Source-Id"] = "test-integration",
                            ["X-Target-Id"] = "123456789"
                        }
                    })
                end)

                assert.is_equal(403, response.status)
            end)

            it("should allow passthrough when source identifier and target identifier are the same", function()

                local response = send_request({
                    method = "GET",
                    path = "/echo",
                    headers = {
                        ["X-Source-Id"] = "some-customer-name",
                        ["X-Target-Id"] = "some-customer-name"
                    }
                })

                assert.is_equal(200, response.status)
            end)

            it("should allow request when target identifier is not present on request", function()

                local response = send_request({
                    method = "GET",
                    path = "/echo",
                    headers = {
                        ["X-Source-Id"] = "test-integration"
                    }
                })

                assert.is_equal(200, response.status)
            end)

            it("should block request when source identifier is not present on request", function()

                local response = send_request({
                    method = "GET",
                    path = "/echo"
                })

                assert.is_equal(403, response.status)
                assert.is_equal("Forbidden", response.body.message)
                assert.is_equal("application/json; charset=utf-8", response.headers["Content-Type"])
            end)

            it("should allow request when target identifier is configured as a wildcard in settings", function()

                send_admin_request({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "other-test-integration",
                        target_identifier = "*"
                    }
                })

                local response = send_request({
                    method = "GET",
                    path = "/echo",
                    headers = {
                        ["X-Source-Id"] = "other-test-integration",
                        ["X-Target-Id"] = "123456789"
                    }
                })

                assert.is_equal(200, response.status)
            end)

            it("should allow request when target identifier is configured as a specific customer ID in settings", function()

                send_admin_request({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "test-integration",
                        target_identifier = "1234567890"
                    }
                })

                local response = send_request({
                    method = "GET",
                    path = "/echo",
                    headers = {
                        ["X-Source-Id"] = "test-integration",
                        ["X-Target-Id"] = "1234567890"
                    }
                })

                assert.is_equal(200, response.status)
            end)

        end)

        context("with custom reject config", function()

            it("should respond with custom message on rejection when configured accordingly", function()

                kong_sdk.plugins:create({
                    service_id = service.id,
                    name = "header-based-request-termination",
                    config = {
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id",
                        message = '{"message":"So long and thanks for all the fish!"}'
                    }
                })

                local response = send_request({
                    method = "GET",
                    path = "/echo",
                    headers = {
                        ["X-Source-Id"] = "test-integration",
                        ["X-Target-Id"] = "123456789"
                    }
                })

                assert.is_equal(403, response.status)
                assert.same({ message = "So long and thanks for all the fish!" }, response.body)
                assert.is_equal("application/json; charset=utf-8", response.headers["Content-Type"])
            end)

            it("should respond with custom status code on rejection when configured accordingly", function()

                kong_sdk.plugins:create({
                    service_id = service.id,
                    name = "header-based-request-termination",
                    config = {
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id",
                        status_code = 503
                    }
                })

                local response = send_request({
                    method = "GET",
                    path = "/echo",
                    headers = {
                        ["X-Source-Id"] = "test-integration",
                        ["X-Target-Id"] = "123456789"
                    }
                })

                assert.is_equal(503, response.status)
            end)

        end)

        context("with log only mode", function()

            context("log_only enabled", function()

                before_each(function()
                    kong_sdk.plugins:create({
                        service_id = service.id,
                        name = "header-based-request-termination",
                        config = {
                            source_header = "X-Source-Id",
                            target_header = "X-Target-Id",
                            log_only = true
                        }
                    })
                end)

                it("should not reject request when settings cannot be found", function()

                    local response = send_request({
                        method = "GET",
                        path = "/echo",
                        headers = {
                            ["X-Source-Id"] = "test-integration",
                            ["X-Target-Id"] = "123456789"
                        }
                    })

                    assert.is_equal(200, response.status)
                end)

                it("should not reject request when source header is missing", function()

                    local response = send_request({
                        method = "GET",
                        path = "/echo",
                        headers = {
                            ["X-Source-Id"] = "test-integration",
                            ["X-Target-Id"] = "123456789"
                        }
                    })

                    assert.is_equal(200, response.status)
                end)

            end)

            context("darklaunch_mode enabled", function()

                before_each(function()
                    kong_sdk.plugins:create({
                        service_id = service.id,
                        name = "header-based-request-termination",
                        config = {
                            source_header = "X-Source-Id",
                            target_header = "X-Target-Id",
                            log_only = true,
                            darklaunch_mode = true
                        }
                    })
                end)

                it("should add block decision as header", function()

                    local response = send_request({
                        method = "GET",
                        path = "/echo",
                        headers = {
                            ["X-Source-Id"] = "test-integration",
                            ["X-Target-Id"] = "darklaunch-blocked-customer"
                        }
                    })

                    assert.is_equal(200, response.status)
                    assert.is_equal("block", response.body.headers["x-request-termination-decision"])
                end)

                it("should add allow decision as header when every customer has access", function()

                    send_admin_request({
                        method = "POST",
                        path = "/integration-access-settings",
                        body = {
                            source_identifier = "darklaunch-allow-every",
                            target_identifier = "*"
                        }
                    })

                    local response = send_request({
                        method = "GET",
                        path = "/echo",
                        headers = {
                            ["X-Source-Id"] = "darklaunch-allow-every",
                            ["X-Target-Id"] = "123456789"
                        }
                    })

                    assert.is_equal(200, response.status)
                    assert.is_equal("allow", response.body.headers["x-request-termination-decision"])
                end)

                it("should add allow decision as header when specific customer has access", function()

                    send_admin_request({
                        method = "POST",
                        path = "/integration-access-settings",
                        body = {
                            source_identifier = "test-integration",
                            target_identifier = "darklaunch-allow-customer"
                        }
                    })

                    local response = send_request({
                        method = "GET",
                        path = "/echo",
                        headers = {
                            ["X-Source-Id"] = "test-integration",
                            ["X-Target-Id"] = "darklaunch-allow-customer"
                        }
                    })

                    assert.is_equal(200, response.status)
                    assert.is_equal("allow", response.body.headers["x-request-termination-decision"])
                end)

            end)

            context("darklaunch_mode disabled", function()

                before_each(function()
                    kong_sdk.plugins:create({
                        service_id = service.id,
                        name = "header-based-request-termination",
                        config = {
                            source_header = "X-Source-Id",
                            target_header = "X-Target-Id",
                            log_only = true,
                            darklaunch_mode = false
                        }
                    })
                end)

                it("should not add decision as header", function()

                    local response = send_request({
                        method = "GET",
                        path = "/echo",
                        headers = {
                            ["X-Source-Id"] = "test-integration",
                            ["X-Target-Id"] = "darklaunch-blocked-customer"
                        }
                    })

                    assert.is_equal(200, response.status)
                    assert.is_nil(response.body.headers["x-request-termination-decision"])
                end)

                it("should not add allow decision as header when every customer has access", function()

                    send_admin_request({
                        method = "POST",
                        path = "/integration-access-settings",
                        body = {
                            source_identifier = "darklaunch-allow-every",
                            target_identifier = "*"
                        }
                    })

                    local response = send_request({
                        method = "GET",
                        path = "/echo",
                        headers = {
                            ["X-Source-Id"] = "darklaunch-allow-every",
                            ["X-Target-Id"] = "123456789"
                        }
                    })

                    assert.is_equal(200, response.status)
                    assert.is_nil(response.body.headers["x-request-termination-decision"])
                end)

                it("should add allow decision as header when specific customer has access", function()

                    send_admin_request({
                        method = "POST",
                        path = "/integration-access-settings",
                        body = {
                            source_identifier = "test-integration",
                            target_identifier = "darklaunch-allow-customer"
                        }
                    })

                    local response = send_request({
                        method = "GET",
                        path = "/echo",
                        headers = {
                            ["X-Source-Id"] = "test-integration",
                            ["X-Target-Id"] = "darklaunch-allow-customer"
                        }
                    })

                    assert.is_equal(200, response.status)
                    assert.is_nil(response.body.headers["x-request-termination-decision"])
                end)

            end)

        end)

        context("with log only disabled and darklaunch enabled", function()

            it("should not add block decision as header", function()

                kong_sdk.plugins:create({
                    service_id = service.id,
                    name = "header-based-request-termination",
                    config = {
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id",
                        log_only = false,
                        darklaunch_mode = true
                    }
                })

                send_admin_request({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "darklaunch-without-log-only",
                        target_identifier = "darklaunch-allow-customer"
                    }
                })

                local response = send_request({
                    method = "GET",
                    path = "/echo",
                    headers = {
                        ["X-Source-Id"] = "darklaunch-without-log-only",
                        ["X-Target-Id"] = "darklaunch-allow-customer"
                    }
                })

                assert.is_nil(response.body.headers["x-request-termination-decision"])
            end)

        end)

        context("with caching", function()

            it("should not reject request if db is wiped", function()

                kong_sdk.plugins:create({
                    service_id = service.id,
                    name = "header-based-request-termination",
                    config = {
                        source_header = "X-Source-Id",
                        target_header = "X-Target-Id"
                    }
                })

                send_admin_request({
                    method = "POST",
                    path = "/integration-access-settings",
                    body = {
                        source_identifier = "test-integration1",
                        target_identifier = "*"
                    }
                })

                local response = send_request({
                    method = "GET",
                    path = "/echo",
                    headers = {
                        ["X-Source-Id"] = "test-integration1",
                        ["X-Target-Id"] = "123456789"
                    }
                })

                assert.is_equal(200, response.status)

                helpers.db:truncate()

                local response = send_request({
                    method = "GET",
                    path = "/echo",
                    headers = {
                        ["X-Source-Id"] = "test-integration1",
                        ["X-Target-Id"] = "123456789"
                    }
                })

                assert.is_equal(200, response.status)
            end)

        end)

    end)
end)
