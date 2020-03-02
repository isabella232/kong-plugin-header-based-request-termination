local cjson = require "cjson"
local typedefs = require "kong.db.schema.typedefs"

local function decode_json(message_template)
    return cjson.decode(message_template)
end

local function is_json_object(message_template)
    local first_char = message_template:sub(1, 1)
    local last_char = message_template:sub(-1)

    return first_char == "{" and last_char == "}"
end

local function ensure_message_is_valid_json(message)
    if is_json_object(message) then
        local parse_succeeded = pcall(decode_json, message)

        if parse_succeeded then
            return true
        end
    end

    return false, "message should be valid JSON object"
end

return {
    name = "header-based-request-termination",
    fields = {
        {
            consumer = typedefs.no_consumer
        },
        {
            config = {
                type = "record",
                fields = {
                    { source_header = { type = "string", required = true } },
                    { target_header = { type = "string", required = true } },
                    { status_code = { type = "number", default = 403 } },
                    { message = { type = "string", default = '{"message": "Forbidden"}', custom_validator = ensure_message_is_valid_json } },
                    { log_only = { type = "boolean", default = false } },
                    { darklaunch_mode = { type = "boolean", default = false } }
                }
            }
        }
    },
}
