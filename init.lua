-- Lua bytecode cache — must run before anything else is required
vim.loader.enable()

require("config.lazy")
require("config.init")
