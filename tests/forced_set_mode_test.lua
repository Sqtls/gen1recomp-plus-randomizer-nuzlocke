local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local saved = {}
local hooks = {}
local listeners = {}
local mod = {
  exports = {},
  save = { get = function(_, key, default)
    if saved[key] == nil then return default end
    return saved[key]
  end },
  hooks = { wrap = function(_, name, callback) hooks[name] = callback end },
  events = { on = function(_, name, callback) listeners[name] = callback end },
}

local BattleState = {
  shiftOfferAllowed = function() return true end,
}
package.loaded[table.concat(
  { "src", "ui", "gen2", "Battle" .. "State" }, ".")] = BattleState

local feature = assert(loadfile(root .. "/features/forced_set_mode.lua"))()
feature.install(mod)

eq(BattleState.shiftOfferAllowed({}), false,
  "enabled Set mode removes the post-KO free-switch offer")

saved.forced_set_mode = false
eq(BattleState.shiftOfferAllowed({}), true,
  "disabling the rule restores the vanilla post-KO switch offer")

saved.forced_set_mode = true
local game = { options = { battleStyle = "SHIFT" }, save = {} }
listeners["game.ready"]({ game = game })
eq(game.options.battleStyle, "SET",
  "enabled rule immediately forces the live Gold option to Set")

local rows = hooks["ui.options.rows"](
  function(_, value) return value end, game, {
    { id = "textSpeed", values = { "FAST", "MID", "SLOW" } },
    { id = "battleStyle", key = "battleStyle",
      values = { "SHIFT", "SET" },
      display = { SHIFT = "SHIFT", SET = "SET  " } },
  })
eq(#rows[2].values, 1, "enabled rule disables the Shift choice")
eq(rows[2].values[1], "SET", "Battle Style row exposes only Set mode")

saved.forced_set_mode = false
game.options.battleStyle = "SHIFT"
rows = hooks["ui.options.rows"](
  function(_, value) return value end, game, {
    { id = "battleStyle", key = "battleStyle",
      values = { "SHIFT", "SET" } },
  })
eq(#rows[1].values, 2,
  "disabling the rule restores both Battle Style choices")
eq(game.options.battleStyle, "SHIFT",
  "disabled rule does not overwrite the player's Battle Style")

print("forced Set mode: " .. checks .. " checks passed")
