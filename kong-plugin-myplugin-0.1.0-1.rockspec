package = "kong-plugin-header-based-request-termination"
version = "0.1.0-1"
supported_platforms = {"linux", "macosx"}
source = {
  url = "git+https://github.com/emartech/kong-plugin-boilerplate.git",
  tag = "0.1.0"
}
description = {
  summary = "Boilerplate for Kong API gateway plugins.",
  homepage = "https://github.com/emartech/kong-plugin-boilerplate",
  license = "MIT"
}
dependencies = {
  "lua ~> 5.1",
  "classic 0.1.0-1",
  "kong-lib-logger >= 0.3.0-1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.header-based-request-termination.handler"] = "kong/plugins/header-based-request-termination/handler.lua",
    ["kong.plugins.header-based-request-termination.schema"] = "kong/plugins/header-based-request-termination/schema.lua",
  }
}
