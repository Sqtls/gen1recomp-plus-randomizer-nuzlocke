local GiftEncounters = {}

local World = require("src.world.gen2.World")
local PrizeMenu = require("src.ui.gen2.PrizeMenu")

local REFUSAL = "This area's encounter\nis already used!"

local function setting(mod)
  return mod.save:get("gift_encounters", "bonus")
end

local function area(mod, game)
  local current = mod.world:current()
  local mapId = current and current.mapId or "UNKNOWN"
  local maps = game and game.data and game.data.gen2Maps
  local landmark = maps and maps[mapId] and maps[mapId].landmark
  if type(landmark) == "number" and landmark > 0 then
    return "LANDMARK:" .. landmark, mapId
  end
  return "MAP:" .. mapId, mapId
end

local function ledger(mod)
  local areas = mod.save:get("encounter_areas")
  if type(areas) ~= "table" then
    areas = {}
    mod.save:set("encounter_areas", areas)
  end
  return areas
end

local function available(mod, game)
  if setting(mod) == "bonus" then return true end
  local key = area(mod, game)
  return ledger(mod)[key] == nil
end

local function claim(mod, game, species)
  if setting(mod) ~= "area" then return end
  local key, mapId = area(mod, game)
  local areas = ledger(mod)
  areas[key] = {
    status = "caught", species = species, mapId = mapId, result = "gift",
  }
  mod.save:set("encounter_areas", areas)
end

local function refuseScript(world)
  local running = coroutine.running()
  if running then
    coroutine.yield({ kind = "text", text = REFUSAL })
  elseif world then
    world.lastText = REFUSAL
  end
  if world and world.vm then world.vm.aborted = true end
end

function GiftEncounters.install(mod)
  local wrappedVms = setmetatable({}, { __mode = "k" })
  local loadWorld = World.load
  assert(type(loadWorld) == "function",
    "Gold scripted gift enforcement is unavailable; update this mod")
  World.load = function(world, ...)
    local result = loadWorld(world, ...)
    local vm = world and world.vm
    if not vm or wrappedVms[vm] then return result end
    wrappedVms[vm] = true

    local givePoke = vm.givePokeFn
    if type(givePoke) == "function" then
      vm.givePokeFn = function(...)
        local game = world.game or mod.game
        if not available(mod, game) then
          refuseScript(world)
          return nil
        end
        local party = game and game.save and game.save.party or {}
        local before = #party
        local gift = givePoke(...)
        local mon = #party > before and party[#party]
          or type(gift) == "table" and gift.mon or nil
        if mon then claim(mod, game, mon.species) end
        return gift
      end
    end

    local giveEgg = vm.giveEggFn
    if type(giveEgg) == "function" then
      vm.giveEggFn = function(...)
        local game = world.game or mod.game
        if not available(mod, game) then
          refuseScript(world)
          return false
        end
        local party = game and game.save and game.save.party or {}
        local before = #party
        local given = giveEgg(...)
        local mon = #party > before and party[#party] or nil
        if given and mon then claim(mod, game, mon.species) end
        return given
      end
    end
    return result
  end

  local checkPrize = PrizeMenu.check
  local buyPrize = PrizeMenu.buy
  local refusePrize = PrizeMenu.refuse
  assert(type(checkPrize) == "function" and type(buyPrize) == "function"
      and type(refusePrize) == "function",
    "Gold Game Corner gift enforcement is unavailable; update this mod")

  PrizeMenu.check = function(save, counter, prize, data, ...)
    local reason = checkPrize(save, counter, prize, data, ...)
    if reason ~= "ok" or not (counter and counter.kind == "mon") then
      return reason
    end
    if not available(mod, mod.game) then return "gift_area" end
    return reason
  end

  PrizeMenu.buy = function(save, counter, prize, data, ...)
    local before = #(save and save.party or {})
    local reason = buyPrize(save, counter, prize, data, ...)
    if reason == "ok" and counter and counter.kind == "mon"
        and #(save and save.party or {}) > before then
      claim(mod, mod.game, prize and prize.id)
    end
    return reason
  end

  PrizeMenu.refuse = function(menu, reason, ...)
    if reason == "gift_area" then
      menu:say({ REFUSAL }, function() menu:close() end)
      return
    end
    return refusePrize(menu, reason, ...)
  end
end

return GiftEncounters
