local LevelCaps = {}

local JOHTO = {
  { badge = "ZEPHYR", index = 1, cap = 9, target = "FALKNER" },
  { badge = "HIVE", index = 2, cap = 16, target = "BUGSY" },
  { badge = "PLAIN", index = 3, cap = 20, target = "WHITNEY" },
  { badge = "FOG", index = 4, cap = 25, target = "MORTY" },
  { badge = "STORM", index = 6, cap = 30, target = "CHUCK" },
  { badge = "GLACIER", index = 7, cap = 31, target = "PRYCE" },
  { badge = "MINERAL", index = 5, cap = 35, target = "JASMINE" },
  { badge = "RISING", index = 8, cap = 40, target = "CLAIR" },
}

local KANTO = {
  "BOULDER", "CASCADE", "THUNDER", "RAINBOW",
  "SOUL", "MARSH", "VOLCANO", "EARTH",
}

local RED_EVENT = 1890
local Mon = require("src.battle.gen2.Mon")

local function saveOf(gameOrSave)
  if type(gameOrSave) ~= "table" then return {} end
  return gameOrSave.save or gameOrSave
end

local function owns(store, name, index)
  return type(store) == "table"
    and (store[name] == true or store[index] == true)
end

local function hallEntered(save)
  local hall = save.hallOfFame
  if type(hall) ~= "table" then return false end
  return hall.entered == true or (tonumber(hall.count) or 0) > 0 or #hall > 0
end

local function eventSet(gameOrSave, save, id)
  local events = gameOrSave and gameOrSave.world
    and gameOrSave.world.events
  if events and type(events.get) == "function" then return events:get(id) end
  local bytes = save.events
  if type(bytes) ~= "table" then return false end
  local byte = math.floor(id / 8)
  local value = tonumber(bytes[byte] or bytes[tostring(byte)]) or 0
  return math.floor(value / (2 ^ (id % 8))) % 2 == 1
end

function LevelCaps.current(gameOrSave)
  local save = saveOf(gameOrSave)
  local badges = save.player and save.player.badges
  for _, milestone in ipairs(JOHTO) do
    if not owns(badges, milestone.badge, milestone.index) then
      return milestone.cap, milestone.target
    end
  end
  if not hallEntered(save) then return 50, "ELITE FOUR" end

  local kanto = save.player and save.player.kantoBadges
  if owns(kanto, "EARTH", 8) then
    if eventSet(gameOrSave, save, RED_EVENT) then return nil, "COMPLETE" end
    return 81, "RED"
  end
  local count = 0
  for index, badge in ipairs(KANTO) do
    if owns(kanto, badge, index) then count = count + 1 end
  end
  if count >= 7 then return 58, "BLUE" end
  return 50, "KANTO"
end

function LevelCaps.install(mod)
  mod.exports.levelCaps = { current = LevelCaps.current }

  local function enabled()
    return mod.save:get("level_caps", true) == true
  end

  mod.hooks:wrap("exp.gain", function(next, ctx)
    local amount = math.max(0, tonumber(next(ctx)) or 0)
    if not enabled() then return amount end
    local mon = ctx and ctx.mon
    local game = mod.game
    local cap = LevelCaps.current(game)
    if not (mon and cap) then return amount end
    if (mon.level or 1) >= cap then return 0 end
    local data = game and game.data
    local def = data and data.pokemon and data.pokemon[mon.species]
    if not def then return amount end
    local growth = Mon.growthFor(data, def.growthRate)
    local threshold = Mon.experienceForLevel(growth, cap)
    local remaining = math.max(0, threshold - (mon.experience or 0))
    return math.min(amount, remaining)
  end, 1000)

  local ItemEffects = require("src.core.gen2.ItemEffects")
  local useOnMon = ItemEffects.useOnMon
  assert(type(useOnMon) == "function",
    "Gold Rare Candy level-cap enforcement is unavailable; update this mod")
  ItemEffects.useOnMon = function(itemId, mon, data, ...)
    if enabled() and itemId == "RARE_CANDY" then
      local cap = LevelCaps.current(mod.game)
      if cap and mon and (mon.level or 1) >= cap then
        return { used = false,
          text = ("The level cap is\nlevel %d!"):format(cap) }
      end
    end
    return useOnMon(itemId, mon, data, ...)
  end

  local function clampExperience(mon, data, cap)
    if not (mon and cap) then return end
    local def = data and data.pokemon and data.pokemon[mon.species]
    if not def then return end
    local growth = Mon.growthFor(data, def.growthRate)
    local threshold = Mon.experienceForLevel(growth, cap)
    if (mon.experience or 0) > threshold then mon.experience = threshold end
  end

  local Breeding = require("src.core.gen2.Breeding")
  local dayCareStep = Breeding.dayCareStep
  local withdraw = Breeding.withdraw
  assert(type(dayCareStep) == "function" and type(withdraw) == "function",
    "Gold Day Care level-cap enforcement is unavailable; update this mod")

  Breeding.dayCareStep = function(data, save, ...)
    local results = { dayCareStep(data, save, ...) }
    if enabled() then
      local cap = LevelCaps.current({ save = save })
      local dayCare = Breeding.dayCare(save)
      clampExperience(dayCare and dayCare.man and dayCare.man.mon, data, cap)
      clampExperience(dayCare and dayCare.lady and dayCare.lady.mon, data, cap)
    end
    return unpack(results)
  end

  Breeding.withdraw = function(data, save, which, ...)
    if enabled() then
      local dayCare = Breeding.dayCare(save)
      local side = dayCare and dayCare[which]
      clampExperience(side and side.mon, data,
        LevelCaps.current({ save = save }))
    end
    return withdraw(data, save, which, ...)
  end
end

return LevelCaps
