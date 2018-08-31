return {
    no_consumer = true,
    fields = {
        source_header = { type = "string", required = true },
        target_header = { type = "string", required = true },
        status_code = { type = "number", default = 403 },
        message = { type = "string" },
        log_only = { type = "boolean", default = false },
    }
}
