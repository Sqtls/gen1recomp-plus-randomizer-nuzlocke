local BreedingEggs = {}

local Breeding = require("src.core.gen2.Breeding")
local DayCareMenu = require("src.ui.gen2.DayCareMenu")

local FORBIDDEN = { { "Breeding EGGS are", "not allowed." } }
local AREA_USED = { { "This area's", "encounter is used." } }

local function setting(mod)
  return mod.save:get("breeding_eggs", "forbid")
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
  if setting(mod) == "forbid" then return false end
  local key = area(mod, game)
  return ledger(mod)[key] == nil
end

local function claim(mod, game, egg)
  if setting(mod) ~= "area" then return end
  local key, mapId = area(mod, game)
  local areas = ledger(mod)
  areas[key] = {
    status = "caught", species = egg and egg.species, mapId = mapId,
    result = "breeding",
  }
  mod.save:set("encounter_areas", areas)
  local dayCare = game and game.save and game.save.dayCare
  if dayCare then
    dayCare.compatible = false
    dayCare.hasEgg = false
    dayCare.egg = nil
    dayCare.stepsToEgg = 0
  end
end

function BreedingEggs.install(mod)
  local initBreeding = Breeding.initBreeding
  local collectEgg = Breeding.collectEgg
  assert(type(initBreeding) == "function" and type(collectEgg) == "function",
    "Gold Day-Care Egg enforcement is unavailable; update this mod")

  Breeding.initBreeding = function(data, save, ...)
    local game = mod.game or { data = data, save = save }
    if not available(mod, game) then
      local dayCare = Breeding.dayCare(save)
      if dayCare then dayCare.compatible = false end
      return false
    end
    return initBreeding(data, save, ...)
  end

  Breeding.collectEgg = function(data, save, ...)
    local game = mod.game or { data = data, save = save }
    if not available(mod, game) then return false, "nuzlocke_egg_policy" end
    local ok, egg, extra = collectEgg(data, save, ...)
    if ok then claim(mod, game, egg) end
    return ok, egg, extra
  end

  local startOutside = DayCareMenu.startOutside
  assert(type(startOutside) == "function",
    "Gold Day-Care Egg screen enforcement is unavailable; update this mod")
  DayCareMenu.startOutside = function(menu, ...)
    local policy = setting(mod)
    local game = menu and menu.game or mod.game
    if policy == "forbid" then
      return menu:say(FORBIDDEN, function() menu:close() end)
    end
    if policy == "area" and not available(mod, game) then
      return menu:say(AREA_USED, function() menu:close() end)
    end
    return startOutside(menu, ...)
  end
end

return BreedingEggs
