local cjson = require "cjson"
local Logger = require "logger"

local kong = kong
local ngx = ngx

local ALL_ACCESS = "*"

local function log_termination(message, query)
    Logger.getInstance(ngx):logWarning({
        msg = message,
        uri = ngx.var.request_uri,
        source_identifier = query.source_identifier,
        target_identifier = query.target_identifier
    })
end

local function find_access_in_db(source_identifier, target_identifier)
    local all_access_query = {
        source_identifier = source_identifier,
        target_identifier = ALL_ACCESS
    }

    local target_access_query = {
        source_identifier = source_identifier,
        target_identifier = target_identifier
    }

    local db = kong.dao.integration_access_settings

    return db:count(all_access_query) > 0 or db:count(target_access_query) > 0
end

local function find_access(source_identifier, target_identifier)
    local cache_key = kong.dao.integration_access_settings:cache_key(source_identifier, target_identifier)
    local has_access = kong.cache:get(cache_key, nil, find_access_in_db, source_identifier, target_identifier)

    return has_access
end

local function set_darklaunch_header(has_access)
    local decision = has_access and "allow" or "block"

    kong.service.request.set_header("x-request-termination-decision", decision)
end

local Access = {}

function Access.execute(conf)
    local source_header_value = kong.request.get_header(conf.source_header)
    local target_header_value = kong.request.get_header(conf.target_header)

    if not source_header_value then
        if conf.log_only then
            log_termination("Request terminated based on missing source header", {
                target_identifier = target_header_value
            })
            return
        end

        return kong.response.exit(conf.status_code, cjson.decode(conf.message))
    end

    if not target_header_value then
        return
    end

    if source_header_value == target_header_value then
        return
    end

    local has_access = find_access(source_header_value, target_header_value)

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

        return kong.response.exit(conf.status_code, cjson.decode(conf.message))
    end
end

return Access
