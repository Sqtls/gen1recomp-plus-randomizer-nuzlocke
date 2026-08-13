local ForcedSetMode = {}

local BattleState = require("src.ui.gen2.BattleState")

function ForcedSetMode.install(mod)
  local function enabled()
    return mod.save:get("forced_set_mode", true) == true
  end

  local function force(game)
    if not (enabled() and game and game.options) then return false end
    game.options.battleStyle = "SET"
    if game.save then game.save.options = game.options end
    return true
  end

  mod.exports.forcedSetMode = { force = force }

  mod.events:on("game.ready", function(ev)
    force(ev and ev.game or mod.game)
  end)

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local result = next(game, rows)
    if not enabled() or type(result) ~= "table" then return result end
    force(game)
    for index, row in ipairs(result) do
      if row.id == "battleStyle" or row.key == "battleStyle" then
        local locked = {}
        for key, value in pairs(row) do locked[key] = value end
        locked.values = { "SET" }
        locked.step = function(activeGame)
          force(activeGame or game)
          return true
        end
        result[index] = locked
        break
      end
    end
    return result
  end, 1000)

  local shiftOfferAllowed = BattleState.shiftOfferAllowed
  assert(type(shiftOfferAllowed) == "function",
    "Gold Set-mode enforcement is unavailable; update this mod")
  BattleState.shiftOfferAllowed = function(screen, ...)
    if enabled() then
      force(screen and screen.game or mod.game)
      return false
    end
    return shiftOfferAllowed(screen, ...)
  end

  force(mod.game)
end

return ForcedSetMode
