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
local saved = {
  strict_encounters = true,
  permadeath = true,
  nuzlocke_started = true,
}
local dead = { species = "SENTRET", nickname = "SCOUT", level = 8, hp = 0 }
local survivor = { species = "CYNDAQUIL", level = 9, hp = 12 }
local deadMail = { message = "SCOUT'S MAIL" }
local survivorMail = { message = "CYNDAQUIL'S MAIL" }
local game = {
  save = {
    party = { dead, survivor }, boxes = {}, inventory = { REVIVE = 2 },
    mail = { party = { deadMail, survivorMail }, box = {} },
  },
  data = { items = {}, pokemon = {} },
}

local function read(relative)
  local file = assert(io.open(root .. "/" .. relative, "rb"))
  local body = file:read("*a")
  file:close()
  return body
end

local mod = {
  path = root,
  game = game,
  exports = {},
  content = { screens = { register = function() end } },
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
    insertBefore = function(items) return items end,
    insertStepAfter = function(steps) return steps end,
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

print(("permadeath: %d checks passed"):format(checks))
