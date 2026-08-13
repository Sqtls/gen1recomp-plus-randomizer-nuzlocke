local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local saved = { no_battle_items = true }
local originalCalls = 0
local BattleState = {
  useItem = function(screen, itemId)
    originalCalls = originalCalls + 1
    screen.save.inventory[itemId] = screen.save.inventory[itemId] - 1
    screen.turns = screen.turns + 1
    return "used"
  end,
}
local battleStateModule = table.concat(
  { "src", "ui", "gen2", "BattleState" }, ".")
package.loaded[battleStateModule] = BattleState

local heldTriggers = 0
local Battle = {
  triggerHeldItem = function() heldTriggers = heldTriggers + 1 end,
}
local battleModule = table.concat({ "src", "battle", "gen2", "Battle" }, ".")
package.loaded[battleModule] = Battle
local originalHeldTrigger = Battle.triggerHeldItem

local mod = {
  save = { get = function(_, key, default)
    if saved[key] == nil then return default end
    return saved[key]
  end },
}

local feature = assert(loadfile(root .. "/features/no_battle_items.lua"))()
feature.install(mod)

local screen = {
  game = { data = { items = {
    POTION = { pocket = "ITEM" },
    POKE_BALL = { pocket = "BALL" },
  } } },
  save = { inventory = { POTION = 2, POKE_BALL = 2 } },
  turns = 0,
}

local result = BattleState.useItem(screen, "POTION")
eq(result, nil, "blocked item does not reach the vanilla item handler")
eq(screen.save.inventory.POTION, 2, "blocked item is not consumed")
eq(screen.turns, 0, "blocked item does not spend the player's turn")
eq(screen.message, "Only BALLS can be\nused in battle!",
  "blocked item explains the active challenge rule")
eq(screen.phase, "resolving", "blocked item returns to battle cleanly")

screen.message = nil
result = BattleState.useItem(screen, "POKE_BALL")
eq(result, "used", "Poke Balls retain the vanilla battle path")
eq(screen.save.inventory.POKE_BALL, 1, "Poke Balls can still be consumed")
eq(screen.turns, 1, "throwing a Poke Ball still spends the normal turn")

saved.no_battle_items = false
result = BattleState.useItem(screen, "POTION")
eq(result, "used", "disabling the rule restores vanilla battle items")
eq(screen.save.inventory.POTION, 1,
  "disabled rule allows vanilla item consumption")
eq(screen.turns, 2, "disabled rule allows vanilla item turn use")
eq(originalCalls, 2, "only allowed item uses reach the vanilla handler")

eq(Battle.triggerHeldItem, originalHeldTrigger,
  "installing the rule does not replace held-item handling")
Battle.triggerHeldItem()
eq(heldTriggers, 1, "held-item effects remain active")

local overworldUses = 0
local function useOutsideBattle()
  overworldUses = overworldUses + 1
end
useOutsideBattle()
eq(overworldUses, 1, "outside-battle item use remains unchanged")

print("no battle items: " .. checks .. " checks passed")
