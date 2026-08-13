local Permadeath = {}

local function setting(mod, key, default)
  local value = mod.save:get(key)
  if value == nil then return default end
  return value
end

function Permadeath.install(mod)
  local deaths = setmetatable({}, { __mode = "k" })

  local function enabled()
    return mod.save:get("nuzlocke_started") == true
      and setting(mod, "permadeath", true) == true
  end

  mod.events:on("battle.fainted", function(ev)
    if not enabled() then return end
    local battle = ev and ev.battle
    local battler = ev and (ev.mon or ev.battler)
    local mon = battler and battler.mon or battler
    local party = mod.game and mod.game.save and mod.game.save.party
    if not (battle and mon and party) then return end

    local owned = false
    for _, member in ipairs(party) do
      if member == mon then owned = true break end
    end
    if not owned then return end

    local fallen = deaths[battle]
    if not fallen then
      fallen = {}
      deaths[battle] = fallen
    end
    fallen[mon] = true
  end)

  local function removeFallen(game, fallen)
    local save = game and game.save
    if not (fallen and save and save.party) then return end
    for index = #save.party, 1, -1 do
      if fallen[save.party[index]] then
        table.remove(save.party, index)
        local mail = save.mail and save.mail.party
        if mail then
          for slot = index, 5 do mail[slot] = mail[slot + 1] end
          mail[6] = nil
        end
      end
    end
    if #save.party > 0 then return end

    for boxIndex = 1, 14 do
      local box = save.boxes and save.boxes[boxIndex]
      for slot, mon in ipairs(box or {}) do
        if not mon.isEgg and (mon.hp or 0) > 0 then
          save.party[1] = table.remove(box, slot)
          return
        end
      end
    end
  end

  local function finalize(game, battle)
    local fallen = battle and deaths[battle]
    if battle then deaths[battle] = nil end
    removeFallen(game, fallen)
  end

  local BattleState = require("src.ui.gen2.BattleState")
  local applyPartyItem = BattleState.applyPartyItem
  assert(type(applyPartyItem) == "function",
    "Gold BattleState.applyPartyItem is unavailable; update this mod")
  BattleState.applyPartyItem = function(screen, itemId, action, mon, ...)
    local fallen = screen and screen.battle and deaths[screen.battle]
    if action == "revive" and fallen and fallen[mon] then
      local name = mon.nickname or mon.species or "POK\195\169MON"
      screen.message = tostring(name) .. " has died.\nREVIVE refused!"
      screen.messageTimer = 48
      screen.phase = "resolving"
      return
    end
    return applyPartyItem(screen, itemId, action, mon, ...)
  end

  local finishBattle = BattleState.finishBattle
  assert(type(finishBattle) == "function",
    "Gold BattleState.finishBattle is unavailable; update this mod")
  BattleState.finishBattle = function(screen, ...)
    local onDone = screen and screen.onDone
    local completed = false
    local function finish(...)
      if completed then return end
      completed = true
      finalize(screen and screen.game or mod.game, screen and screen.battle)
      if onDone then return onDone(...) end
    end
    if screen then screen.onDone = finish end
    local result = finishBattle(screen, ...)
    finish()
    return result
  end

  local World = require("src.world.gen2.World")
  local poisonFaintScript = World.poisonFaintScript
  assert(type(poisonFaintScript) == "function",
    "Gold World.poisonFaintScript is unavailable; update this mod")
  World.poisonFaintScript = function(world, event, ...)
    local party = world and world.game and world.game.save
      and world.game.save.party or {}
    local fallen = {}
    if enabled() then
      for _, index in ipairs(event and event.fainted or {}) do
        if party[index] then fallen[party[index]] = true end
      end
    end
    local result = poisonFaintScript(world, event, ...)
    removeFallen(world and world.game or mod.game, fallen)
    return result
  end
end

return Permadeath
