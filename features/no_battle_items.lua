local NoBattleItems = {}

local BattleState = require("src.ui.gen2.BattleState")

function NoBattleItems.install(mod)
  local function enabled()
    return mod.save:get("no_battle_items", false) == true
  end

  local useItem = BattleState.useItem
  assert(type(useItem) == "function",
    "Gold battle-item enforcement is unavailable; update this mod")
  BattleState.useItem = function(screen, itemId, ...)
    local game = screen and screen.game or mod.game
    local items = game and game.data and game.data.items
    local item = items and items[itemId]
    if enabled() and not (item and item.pocket == "BALL") then
      screen.message = "Only BALLS can be\nused in battle!"
      screen.messageTimer = 48
      screen.phase = "resolving"
      return
    end
    return useItem(screen, itemId, ...)
  end
end

return NoBattleItems
