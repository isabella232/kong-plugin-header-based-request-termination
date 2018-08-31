local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"
local Logger = require "logger"

local function log_termination(query)
    Logger.getInstance(ngx):logInfo({
        ["msg"] = "Request terminated based on headers",
        ["uri"] = ngx.var.request_uri,
        ["source_identifier"] = query.source_identifier,
        ["target_identifier"] = query.target_identifier
    })
end

local function query_access(dao, query_params)
    local access_settings = dao.integration_access_settings:find_all(query_params)
    return #access_settings > 0
end

local Access = {}

function Access.execute(conf)

    local headers = ngx.req.get_headers()
    local source_header_value = headers[conf.source_header]
    local target_header_value = headers[conf.target_header]

    if not source_header_value then
        error('Source header is not present')
        return
    end

    if not target_header_value then
        return
    end

    local query_params = { source_identifier = source_header_value, target_identifier = '*' }
    local cache_key = singletons.dao.integration_access_settings:cache_key(source_header_value, '*')
    local has_access = singletons.cache:get(cache_key, nil, query_access, singletons.dao, query_params)

    if not has_access then
        if conf.log_only then
            log_termination(query_params)
            return
        end
        responses.send(conf.status_code, conf.message)
    end

end

return Access
