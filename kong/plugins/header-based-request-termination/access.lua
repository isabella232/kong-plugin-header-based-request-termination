local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"
local Logger = require "logger"

local ALL_ACCESS = "*"

local function log_termination(message, query)
    Logger.getInstance(ngx):logWarning({
        msg = message,
        uri = ngx.var.request_uri,
        source_identifier = query.source_identifier,
        target_identifier = query.target_identifier
    })
end

local function query_access(dao, source_identifier, target_identifier)
    local query_params_general = {
        source_identifier = source_identifier,
        target_identifier = ALL_ACCESS
    }

    local query_params_specific = {
        source_identifier = source_identifier,
        target_identifier = target_identifier
    }

    local access_settings_general = dao.integration_access_settings:find_all(query_params_general)
    local access_settings_specific = dao.integration_access_settings:find_all(query_params_specific)

    return #access_settings_general + #access_settings_specific > 0
end

local function set_darklaunch_header(has_access)
    local decision = has_access and "allow" or "block"

    kong.service.request.set_header("x-request-termination-decision", decision)
end

local Access = {}

function Access.execute(conf)

    local headers = ngx.req.get_headers()
    local source_header_value = headers[conf.source_header]
    local target_header_value = headers[conf.target_header]

    if not source_header_value then
        if conf.log_only then
            log_termination("Request terminated based on missing source header", {
                target_identifier = target_header_value
            })
            return
        end

        responses.send(conf.status_code, conf.message)
    end

    if not target_header_value then
        return
    end

    if source_header_value == target_header_value then
        return
    end

    local cache_key = singletons.dao.integration_access_settings:cache_key(source_header_value, target_header_value)
    local has_access = singletons.cache:get(cache_key, nil, query_access, singletons.dao, source_header_value, target_header_value)

    if conf.log_only and conf.darklaunch_mode then
        set_darklaunch_header(has_access)
    end

    if not has_access then
        if conf.log_only then
            log_termination("Request terminated based on headers", {
                source_identifier = source_header_value,
                target_identifier = target_header_value
            })
            return
        end

        responses.send(conf.status_code, conf.message)
    end

end

return Access
