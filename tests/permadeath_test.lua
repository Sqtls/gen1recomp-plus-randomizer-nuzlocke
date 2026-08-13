local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local BattleState = {
  useItem = function() end,
  applyPartyItem = function(screen, itemId, action, mon)
    screen.appliedItem = itemId
    screen.save.inventory[itemId] = screen.save.inventory[itemId] - 1
    if action == "revive" then mon.hp = 10 end
  end,
  finishBattle = function(screen)
    if screen.onDone then
      return screen.onDone(screen.battle and screen.battle.outcome, screen.battle)
    end
  end,
}
local battleStateModule = table.concat({ "src", "ui", "gen2", "BattleState" }, ".")
package.loaded[battleStateModule] = BattleState

local World = {
  poisonFaintScript = function(world)
    world.poisonPartyCount = #(world.game.save.party or {})
  end,
}
local worldModule = table.concat({ "src", "world", "gen2", "World" }, ".")
package.loaded[worldModule] = World

local listeners = {}
local registeredScreens = {}
local pushedScreens = {}
local pushObserver
local saved = {
  strict_encounters = true,
  permadeath = true,
  nuzlocke_started = true,
}
local dead = { species = "SENTRET", nickname = "SCOUT", level = 8, hp = 0 }
local survivor = { species = "CYNDAQUIL", level = 9, hp = 12 }
local deadMail = { message = "SCOUT'S MAIL" }
local survivorMail = { message = "CYNDAQUIL'S MAIL" }
local pressed = {}
local game = {
  save = {
    party = { dead, survivor }, boxes = {}, inventory = { REVIVE = 2 },
    mail = { party = { deadMail, survivorMail }, box = {} },
  },
  data = { items = {}, pokemon = {} },
  input = {
    wasPressed = function(_, key) return pressed[key] == true end,
  },
}
local saveDeletes = 0
game.deleteActiveSave = function()
  saveDeletes = saveDeletes + 1
  return true
end

local function read(relative)
  local file = assert(io.open(root .. "/" .. relative, "rb"))
  local body = file:read("*a")
  file:close()
  return body
end

local drawn = {}
love = {
  graphics = {
    setColor = function() end,
    rectangle = function() end,
  },
}

local mod = {
  path = root,
  game = game,
  exports = {},
  content = { screens = { register = function(_, id, screen)
    registeredScreens[id] = screen
  end } },
  hooks = { wrap = function() end },
  events = {
    on = function(_, name, callback)
      listeners[name] = listeners[name] or {}
      listeners[name][#listeners[name] + 1] = callback
    end,
  },
  save = {
    get = function(_, key, default)
      if saved[key] == nil then return default end
      return saved[key]
    end,
    set = function(_, key, value) saved[key] = value end,
  },
  world = { current = function() return { mapId = "ROUTE_29" } end },
  ui = {
    Font = {
      width = function(text) return #text * 8 end,
      draw = function(text, x, y)
        drawn[#drawn + 1] = { text = text, x = x, y = y }
      end,
      drawCode = function(code, x, y)
        drawn[#drawn + 1] = { code = code, x = x, y = y }
      end,
    },
    Theme = { cursor = 0xed },
    insertBefore = function(items) return items end,
    insertStepAfter = function(steps) return steps end,
    push = function(activeGame, id)
      pushedScreens[#pushedScreens + 1] = { game = activeGame, id = id }
      if pushObserver then pushObserver(id) end
    end,
  },
}
function mod:read(relative) return read(relative) end

assert(loadfile(root .. "/main.lua"))()(mod)

local function emit(name, payload)
  for _, callback in ipairs(listeners[name] or {}) do callback(payload) end
end

local battle = { wild = true, party = game.save.party, outcome = "win" }
emit("battle.fainted", {
  battle = battle,
  battler = dead,
  side = { index = 1, key = "player" },
})

local reviveScreen = {
  game = game,
  save = game.save,
  battle = battle,
  phase = "party",
}
BattleState.applyPartyItem(reviveScreen, "REVIVE", "revive", dead)
eq(dead.hp, 0, "dead Pokemon cannot be revived during its battle")
eq(game.save.inventory.REVIVE, 2, "refused Revive is not consumed")
eq(reviveScreen.appliedItem, nil, "dead Pokemon bypasses Gold's Revive effect")
eq(reviveScreen.message, "SCOUT has died.\nREVIVE refused!",
  "refused Revive explains permadeath")

local finished = false
BattleState.finishBattle({
  game = game,
  save = game.save,
  battle = battle,
  onDone = function() finished = true end,
})

eq(finished, true, "Gold finishes the battle normally")
eq(#game.save.party, 1, "fainted party member is permanently removed")
eq(game.save.party[1], survivor, "living party member remains")
eq(game.save.mail.party[1], survivorMail,
  "survivor keeps the mail associated with its shifted party slot")
eq(game.save.mail.party[2], nil, "dead Pokemon's party-mail slot is removed")

local wipedOne = { species = "CYNDAQUIL", level = 10, hp = 0 }
local wipedTwo = { species = "SENTRET", level = 9, hp = 0 }
local backup = { species = "HOOTHOOT", nickname = "NIGHT", level = 7, hp = 18 }
local reserve = { species = "RATTATA", level = 6, hp = 14 }
game.save.party = { wipedOne, wipedTwo }
game.save.boxes = { [1] = { backup, reserve } }
local wipe = { wild = true, party = game.save.party, outcome = "lose" }
emit("battle.fainted", { battle = wipe, battler = wipedOne,
  side = { index = 1, key = "player" } })
emit("battle.fainted", { battle = wipe, battler = wipedTwo,
  side = { index = 1, key = "player" } })

local partyAtRespawn
BattleState.finishBattle({
  game = game,
  save = game.save,
  battle = wipe,
  onDone = function() partyAtRespawn = game.save.party[1] end,
})

eq(#game.save.party, 1, "party wipe withdraws exactly one boxed Pokemon")
eq(game.save.party[1], backup, "first boxed Pokemon saves the run")
eq(partyAtRespawn, backup, "backup is in the party before respawn handling")
eq(#game.save.boxes[1], 1, "rescued Pokemon is removed from its box")
eq(game.save.boxes[1][1], reserve, "remaining box order is preserved")

local egg = { species = "TOGEPI", isEgg = true, hp = 20 }
local faintedBoxed = { species = "PIDGEY", hp = 0 }
local laterBackup = { species = "ZUBAT", level = 5, hp = 11 }
local lastDeath = { species = "RATTATA", level = 6, hp = 0 }
game.save.party = { lastDeath }
game.save.boxes = {
  [1] = { egg, faintedBoxed },
  [2] = { laterBackup },
}
local selectiveWipe = {
  wild = true, party = game.save.party, outcome = "lose",
}
emit("battle.fainted", { battle = selectiveWipe, battler = lastDeath,
  side = { index = 1, key = "player" } })
BattleState.finishBattle({ game = game, save = game.save,
  battle = selectiveWipe })
eq(game.save.party[1], laterBackup,
  "rescue skips Eggs and fainted boxed Pokemon")
eq(#game.save.boxes[1], 2, "skipped box contents remain untouched")
eq(#game.save.boxes[2], 0, "living rescue is removed from its own box")

saved.permadeath = false
local disabledDeath = { species = "SENTRET", hp = 0 }
game.save.party = { disabledDeath }
local disabledBattle = {
  wild = true, party = game.save.party, outcome = "lose",
}
emit("battle.fainted", { battle = disabledBattle, battler = disabledDeath,
  side = { index = 1, key = "player" } })
BattleState.finishBattle({ game = game, save = game.save,
  battle = disabledBattle })
eq(game.save.party[1], disabledDeath,
  "disabled permadeath preserves a fainted party member")

saved.permadeath = true
saved.nuzlocke_started = false
local earlyDeath = { species = "CYNDAQUIL", hp = 0 }
game.save.party = { earlyDeath }
local earlyBattle = { wild = true, party = game.save.party, outcome = "lose" }
emit("battle.fainted", { battle = earlyBattle, battler = earlyDeath,
  side = { index = 1, key = "player" } })
BattleState.finishBattle({ game = game, save = game.save,
  battle = earlyBattle })
eq(game.save.party[1], earlyDeath,
  "faint before the first Ball does not trigger permadeath")

saved.nuzlocke_started = true
local healthyParty = { species = "CYNDAQUIL", hp = 12 }
local enemy = { species = "SENTRET", hp = 0 }
game.save.party = { healthyParty }
local enemyBattle = {
  wild = true, party = game.save.party, enemy = enemy, outcome = "win",
}
emit("battle.fainted", { battle = enemyBattle, battler = enemy,
  side = { index = 2, key = "enemy" } })
BattleState.finishBattle({ game = game, save = game.save,
  battle = enemyBattle })
eq(game.save.party[1], healthyParty,
  "enemy faint never removes a player Pokemon")

local poisonDeath = { species = "SENTRET", nickname = "SCOUT", hp = 0 }
local poisonSurvivor = { species = "CYNDAQUIL", hp = 9 }
game.save.party = { poisonDeath, poisonSurvivor }
local world = { game = game }
World.poisonFaintScript(world, { fainted = { 1 }, whiteout = false })
eq(world.poisonPartyCount, 2,
  "Gold builds its poison-faint message before deletion")
eq(#game.save.party, 1, "overworld poison faint triggers permadeath")
eq(game.save.party[1], poisonSurvivor,
  "overworld poison faint preserves living party members")

local finalDeath = { species = "CYNDAQUIL", hp = 0 }
game.save.party = { finalDeath }
game.save.boxes = {}
saved.nuzlocke_game_over = nil
pushedScreens = {}
local terminalOrder = {}
game.deleteActiveSave = function()
  saveDeletes = saveDeletes + 1
  terminalOrder[#terminalOrder + 1] = "delete_save"
  return true
end
pushObserver = function()
  terminalOrder[#terminalOrder + 1] = "game_over"
end
local terminalWipe = {
  wild = true, party = game.save.party, outcome = "lose",
}
emit("battle.fainted", { battle = terminalWipe, battler = finalDeath,
  side = { index = 1, key = "player" } })
local respawnComplete = false
BattleState.finishBattle({
  game = game,
  save = game.save,
  battle = terminalWipe,
  onDone = function()
    respawnComplete = true
    terminalOrder[#terminalOrder + 1] = "respawn"
  end,
})
eq(#game.save.party, 0,
  "terminal wipe removes the final fainted Pokemon")
eq(saved.nuzlocke_game_over, true,
  "terminal wipe records game over")
eq(saveDeletes, 1,
  "terminal wipe deletes the active save exactly once")
eq(#pushedScreens, 1,
  "terminal wipe opens exactly one game-over screen")
eq(pushedScreens[1] and pushedScreens[1].id,
  "Gen1RecompPlusNuzlockeGameOver",
  "terminal wipe opens the Nuzlocke game-over screen")
eq(respawnComplete, true,
  "blackout respawn completes before the game-over screen opens")
eq(table.concat(terminalOrder, ","), "delete_save,respawn,game_over",
  "save deletion happens before respawn and the game-over screen")

local gameOverFactory = registeredScreens.Gen1RecompPlusNuzlockeGameOver
eq(type(gameOverFactory), "table", "game-over screen is registered")
local gameOverScreen = gameOverFactory.new(game)
eq(gameOverScreen.title, "NUZLOCKE FAILED",
  "terminal screen clearly announces the failed run")
eq(gameOverScreen.action, "RESTART GAME",
  "terminal screen has one restart action")
eq(gameOverScreen.pages and gameOverScreen.pages[2].name, "ENCOUNTERS",
  "terminal screen includes the run report")
drawn = {}
gameOverScreen:draw()
eq(drawn[1].text, "NUZLOCKE FAILED",
  "failed title is drawn")
eq(drawn[1].x, 20,
  "failed title is horizontally centered")
local restartIndex
for index, call in ipairs(drawn) do
  if call.text == "RESTART GAME" then restartIndex = index break end
end
eq(type(restartIndex), "number", "restart is the only drawn action")
eq(drawn[restartIndex].x, 36, "restart label is centered with its cursor")
eq(drawn[restartIndex - 1].x, 28,
  "restart row including its cursor is horizontally centered")
local returnedToTitle = false
game.returnToTitle = function() returnedToTitle = true end
pressed = { b = true }
gameOverScreen:update()
eq(returnedToTitle, false,
  "B cannot dismiss the failed-run screen")
pressed = { a = true }
gameOverScreen:update()
eq(returnedToTitle, true,
  "restart returns to the title after save deletion")
pressed = {}

local strandedBackup = { species = "PIDGEY", hp = 15 }
game.save.party = {}
game.save.boxes = { [1] = { strandedBackup } }
saved.nuzlocke_game_over = nil
pushedScreens = {}
emit("save.loaded", { save = game.save })
eq(game.save.party[1], strandedBackup,
  "v0.3.0 empty-party save recovers a living boxed Pokemon")
eq(#pushedScreens, 0,
  "recovered v0.3.0 save does not show game over")

game.save.party = {}
game.save.boxes = {}
saved.nuzlocke_game_over = nil
pushedScreens = {}
local deletesBeforeStrandedGameOver = saveDeletes
emit("save.loaded", { save = game.save })
eq(saved.nuzlocke_game_over, true,
  "v0.3.0 empty-party save with no backup becomes game over")
eq(#pushedScreens, 1,
  "v0.3.0 stranded save opens the terminal screen on load")
eq(saveDeletes, deletesBeforeStrandedGameOver + 1,
  "v0.3.0 stranded save is deleted when classified as game over")

local finalPoisonDeath = { species = "SENTRET", hp = 0 }
game.save.party = { finalPoisonDeath }
game.save.boxes = {}
saved.nuzlocke_game_over = nil
pushedScreens = {}
emit("save.created", { save = game.save })
local deletesBeforePoisonGameOver = saveDeletes
World.poisonFaintScript(world, { fainted = { 1 }, whiteout = true })
eq(saved.nuzlocke_game_over, true,
  "terminal poison wipe records game over")
eq(#pushedScreens, 0,
  "poison game over waits for its asynchronous whiteout")
emit("map.entered", { mapId = "NEW_BARK_TOWN", via = "warp" })
eq(#pushedScreens, 1,
  "poison game over opens after the whiteout warp")
eq(saveDeletes, deletesBeforePoisonGameOver + 1,
  "terminal poison wipe deletes the active save")

local deletedVersion, deletedSlot
local gameVersionModule = table.concat({ "src", "core", "GameVersion" }, ".")
local saveDataModule = table.concat({ "src", "core", "SaveData" }, ".")
package.loaded[gameVersionModule] = { get = function() return "gold" end }
package.loaded[saveDataModule] = {
  activeSlot = function(version)
    eq(version, "gold", "v0.1.80 fallback resolves the Gold save")
    return "slot7"
  end,
  deleteSlot = function(version, slot)
    deletedVersion, deletedSlot = version, slot
    return true
  end,
}
game.deleteActiveSave = nil
game.save.party = {}
game.save.boxes = {}
saved.nuzlocke_game_over = nil
emit("save.created", { save = game.save })
emit("save.loaded", { save = game.save })
eq(deletedVersion, "gold",
  "v0.1.80 fallback deletes from the Gold save registry")
eq(deletedSlot, "slot7",
  "v0.1.80 fallback deletes the active save slot")

print(("permadeath: %d checks passed"):format(checks))
