local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local mod = { exports = {} }
local load = assert(loadfile(root .. "/main.lua"))
local install = load()

assert(type(install) == "function", "main.lua must return a mod installer")
install(mod)
assert(mod.exports.project.generation == 2, "project must target Gen 2")
assert(mod.exports.project.game == "gold", "project must target Gold")
assert(mod.exports.project.status == "foundation",
  "foundation must not claim a gameplay feature")

print("foundation smoke test: 3 checks passed")
