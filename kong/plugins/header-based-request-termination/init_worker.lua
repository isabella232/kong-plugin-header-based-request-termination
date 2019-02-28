local CacheWarmer = require "kong.plugins.header-based-request-termination.cache_warmer"

local kong = kong

local function retrieve_key_from_access_setting(access_setting)
    return { access_setting.source_identifier, access_setting.target_identifier }
end

local ONE_DAY_IN_SECONDS = 86400

local InitWorker = {}

function InitWorker.execute()
    local cache_warmer = CacheWarmer(ONE_DAY_IN_SECONDS)

    cache_warmer:cache_all_entities(kong.dao.integration_access_settings, retrieve_key_from_access_setting)
end

return InitWorker
