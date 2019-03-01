local cjson = require "cjson"

local function decode_json(message_template)
    return cjson.decode(message_template)
end

local function is_object(message_template)
    local first_char = message_template:sub(1, 1)
    local last_char = message_template:sub(-1)
    return first_char == '{' and last_char == '}'
end

local function ensure_message_is_valid_json(message)
    local ok = pcall(decode_json, message)

    if not ok or not is_object(message) then
        return false, "message should be valid JSON object"
    end

    return true
end

return {
    no_consumer = true,
    fields = {
        source_header = { type = "string", required = true },
        target_header = { type = "string", required = true },
        status_code = { type = "number", default = 403 },
        message = { type = "string", default = '{"message": "Forbidden"}', func = ensure_message_is_valid_json },
        log_only = { type = "boolean", default = false },
        darklaunch_mode = { type = "boolean", default = false }
    }
}
