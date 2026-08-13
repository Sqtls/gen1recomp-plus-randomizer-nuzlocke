local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local battleStateModule = table.concat({ "src", "ui", "gen2", "BattleState" }, ".")
package.loaded[battleStateModule] = {
  useItem = function() end,
  applyPartyItem = function() end,
  finishBattle = function() end,
}
local worldModule = table.concat({ "src", "world", "gen2", "World" }, ".")
package.loaded[worldModule] = {
  poisonFaintScript = function() end,
  askYesNo = function() end,
}

local function read(relative)
  local file = assert(io.open(root .. "/" .. relative, "rb"))
  local body = file:read("*a")
  file:close()
  return body
end

local mod = {
  path = root,
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
function mod:read(relative) return read(relative) end
local load = assert(loadfile(root .. "/main.lua"))
local install = load()

assert(type(install) == "function", "main.lua must return a mod installer")
install(mod)
assert(mod.exports.project.generation == 2, "project must target Gen 2")
assert(mod.exports.project.game == "gold", "project must target Gold")
assert(mod.exports.project.status
    == "strict-encounters-shiny-clause-permadeath-run-reports-and-mandatory-nicknames",
  "project must report its active feature set")

print("project smoke test: 3 checks passed")
