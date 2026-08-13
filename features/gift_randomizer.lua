local GiftRandomizer = {}

local Breeding = require("src.core.gen2.Breeding")
local Mon = require("src.battle.gen2.Mon")
local PrizeMenu = require("src.ui.gen2.PrizeMenu")
local Specials = require("src.script.gen2.Specials")
local World = require("src.world.gen2.World")

local function setting(mod, key, default)
  local value = mod.save:get(key)
  if value == nil then return default end
  return value
end

local function speciesByIndex(pokemon, index)
  for species, definition in pairs(pokemon or {}) do
    if type(definition) == "table" and definition.index == index then
      return species
    end
  end
end

local function mapId(mod, world)
  local map = world and world.map
  if map and map.id then return map.id end
  local current = mod.world:current()
  return current and current.mapId or "UNKNOWN"
end

local function isElmsLab(world)
  local map = world and world.map
  return map and (map.id == "ELMS_LAB"
    or map.id == "24:5"
    or (map.group == 24 and map.map == 5))
end

local function baseAndHatchable(data, species)
  local pokemon = data and data.pokemon or {}
  local definition = pokemon[species]
  if not definition or Breeding.isNoEggs(definition) then return false end
  for _, candidate in pairs(pokemon) do
    for _, evolution in ipairs(candidate.evolutions or {}) do
      if (evolution.into or evolution.species) == species then return false end
    end
  end
  return true
end

local function prizeLabel(name, cost)
  local price = tostring(cost or 0)
  local spaces = math.max(1, 15 - #tostring(name) - #price)
  return tostring(name) .. string.rep(" ", spaces) .. price
end

function GiftRandomizer.install(mod)
  local shared = assert(mod.exports.wildRandomizer,
    "wild randomizer must be installed before gift randomizer")

  local function enabled()
    return setting(mod, "gift_randomizer", "off") ~= "off"
  end

  local function choose(data, source, scope, egg)
    local mode = setting(mod, "gift_randomizer", "off")
    if mode == "off" then return source end
    local allowLegendaries = setting(mod, "gift_legendaries", "exclude")
      == "allow"
    return shared.chooseSpecies(data, source, mode, scope, 1,
      function(species)
        if egg then
          return not shared.legendary(species)
            and baseAndHatchable(data, species)
        end
        return allowLegendaries or not shared.legendary(species)
      end)
  end

  mod.events:on("pokemon.before_give", function(gift)
    if not enabled() or type(gift) ~= "table" or not gift.species
        or isElmsLab(gift.world) then return end
    local giftMap = mapId(mod, gift.world)
    gift.species = choose(gift.game and gift.game.data or mod.game.data,
      gift.species, table.concat({ "gift", giftMap, gift.species,
        tostring(gift.level or "") }, ":"), false)
  end)

  local wrappedVms = setmetatable({}, { __mode = "k" })
  local loadWorld = World.load
  assert(type(loadWorld) == "function",
    "Gold scripted Egg randomization is unavailable; update this mod")
  World.load = function(world, ...)
    local result = loadWorld(world, ...)
    local vm = world and world.vm
    if not vm or wrappedVms[vm] then return result end
    wrappedVms[vm] = true
    local giveEgg = vm.giveEggFn
    if type(giveEgg) == "function" then
      vm.giveEggFn = function(index, level, ...)
        local game = world.game or mod.game
        local data = game and game.data
        local source = speciesByIndex(data and data.pokemon, index)
        if not enabled() or not source then
          return giveEgg(index, level, ...)
        end
        local replacement = choose(data, source, table.concat({
          "gift_egg", mapId(mod, world), source, tostring(level or ""),
        }, ":"), true)
        local definition = data.pokemon[replacement]
        if not (definition and definition.index) then
          return giveEgg(index, level, ...)
        end
        local party = game and game.save and game.save.party or {}
        local before = #party
        local given = giveEgg(definition.index, level, ...)
        local egg = given and #party > before and party[#party] or nil
        if egg and source == "TOGEPI" then
          egg.nuzlockeOriginalGift = "TOGEPI"
        end
        return given
      end
    end
    return result
  end

  local hatch = Breeding.hatch
  assert(type(hatch) == "function",
    "Gold scripted Egg story compatibility is unavailable; update this mod")
  Breeding.hatch = function(data, save, index, ...)
    local egg = save and save.party and save.party[index]
    local mon, effects = hatch(data, save, index, ...)
    if egg and egg.nuzlockeOriginalGift == "TOGEPI" and effects then
      effects.togepi = true
    end
    return mon, effects
  end

  local buildPrizes = PrizeMenu.buildPrizes
  assert(type(buildPrizes) == "function",
    "Gold Game Corner randomization is unavailable; update this mod")
  PrizeMenu.buildPrizes = function(menu, ...)
    local result = buildPrizes(menu, ...)
    if not enabled() or not (menu.counter and menu.counter.kind == "mon") then
      return result
    end
    local data = menu.data or menu.game and menu.game.data or mod.game.data
    for index, prize in ipairs(menu.prizes or {}) do
      if not prize.cancel and prize.id then
        local replacement = choose(data, prize.id, table.concat({
          "game_corner", mapId(mod), prize.id, tostring(prize.cost or ""),
        }, ":"), false)
        local definition = data and data.pokemon and data.pokemon[replacement]
        if definition then
          local copy = {}
          for key, value in pairs(prize) do copy[key] = value end
          copy.id = replacement
          copy.label = prizeLabel(definition.name or replacement, copy.cost)
          menu.prizes[index] = copy
        end
      end
    end
    return result
  end

  local giveShuckle = Specials.ALL and Specials.ALL.GiveShuckle
  local returnShuckle = Specials.ALL and Specials.ALL.ReturnShuckie
  assert(type(giveShuckle) == "function" and type(returnShuckle) == "function",
    "Gold Shuckie randomization is unavailable; update this mod")

  local randomizedGiveShuckle = function(vm)
    local party = vm and vm.specials and vm.specials.party
      and vm.specials.party() or {}
    local before = #party
    local result = giveShuckle(vm)
    if not enabled() or #party <= before then return result end
    local data = vm and vm.specials and vm.specials.data
      and vm.specials.data() or mod.game.data
    local replacement = choose(data, "SHUCKLE",
      "gift:MANIAS_HOUSE:SHUCKLE:15", false)
    if replacement == "SHUCKLE" then return result end
    local original = party[#party]
    local mon = Mon.new(data, replacement, original.level or 15, {
      nickname = original.nickname, item = original.item, dvs = original.dvs,
      happiness = original.happiness,
    })
    if not mon then return result end
    mon.ot, mon.otId = original.ot, original.otId
    party[#party] = mon
    local areas = mod.save:get("encounter_areas")
    for _, record in pairs(type(areas) == "table" and areas or {}) do
      if record.result == "gift" and record.species == "SHUCKLE" then
        record.species = replacement
      end
    end
    return result
  end

  local randomizedReturnShuckle = function(vm)
    if not enabled() then return returnShuckle(vm) end
    local hooks = vm and vm.specials or {}
    if type(hooks.selectPartyMon) ~= "function" then
      return returnShuckle(vm)
    end
    local picked = Specials.block(vm, function(done)
      hooks.selectPartyMon("choose", function(index, mon)
        done({ index = index, mon = mon })
      end)
    end) or {}
    local mon = picked.mon
    if not mon then vm.scriptVar = Specials.SHUCKIE_REFUSED return end
    local data = hooks.data and hooks.data() or mod.game.data
    local expected = choose(data, "SHUCKLE",
      "gift:MANIAS_HOUSE:SHUCKLE:15", false)
    if mon.species ~= expected or mon.otId ~= Specials.MANIA_OT_ID
        or mon.ot ~= Specials.MANIA_OT then
      vm.scriptVar = Specials.SHUCKIE_WRONG_MON
      return
    end
    if (mon.hp or 0) <= 0 then
      vm.scriptVar = Specials.SHUCKIE_FAINTED
      return
    end
    vm.shuckieHappiness = mon.happiness or 0
    if (mon.happiness or 0) >= Specials.SHUCKIE_HAPPY_THRESHOLD then
      vm.scriptVar = Specials.SHUCKIE_HAPPY
      return
    end
    local party = hooks.party and hooks.party() or {}
    table.remove(party, picked.index)
    vm.scriptVar = Specials.SHUCKIE_RETURNED
  end

  Specials.ALL.GiveShuckle = randomizedGiveShuckle
  Specials.ALL.ReturnShuckie = randomizedReturnShuckle
  if Specials.HANDLERS and Specials.HANDLERS.GiveShuckle == giveShuckle then
    Specials.HANDLERS.GiveShuckle = randomizedGiveShuckle
  end
  if Specials.HANDLERS and Specials.HANDLERS.ReturnShuckie == returnShuckle then
    Specials.HANDLERS.ReturnShuckie = randomizedReturnShuckle
  end

  mod.exports.giftRandomizer = { choose = choose }
end

return GiftRandomizer
