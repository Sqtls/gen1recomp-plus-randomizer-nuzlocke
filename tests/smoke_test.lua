local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local mod = {
  exports = {},
  options = { define = function() end, get = function() end },
  hooks = { wrap = function() end },
  events = { on = function() end },
  content = { screens = { register = function() end } },
  ui = {},
  save = { get = function(_, _, default) return default end,
    set = function() end },
  world = { current = function() return nil end },
}
local load = assert(loadfile(root .. "/main.lua"))
local install = load()

assert(type(install) == "function", "main.lua must return a mod installer")
install(mod)
assert(mod.exports.project.generation == 2, "project must target Gen 2")
assert(mod.exports.project.game == "gold", "project must target Gold")
assert(mod.exports.project.status == "strict-first-encounters",
  "project must report its active feature set")

print("project smoke test: 3 checks passed")
