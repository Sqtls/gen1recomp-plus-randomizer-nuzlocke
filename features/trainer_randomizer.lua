local TrainerRandomizer = {}

local Mon = require("src.battle.gen2.Mon")

local BOSSES = {
  FALKNER = true, BUGSY = true, WHITNEY = true, MORTY = true,
  CHUCK = true, JASMINE = true, PRYCE = true, CLAIR = true,
  WILL = true, KOGA = true, BRUNO = true, KAREN = true, CHAMPION = true,
  BROCK = true, MISTY = true, LT_SURGE = true, ERIKA = true,
  JANINE = true, SABRINA = true, BLAINE = true, BLUE = true, RED = true,
  RIVAL1 = true, RIVAL2 = true,
}

local RIVAL_STARTERS = {
  CHIKORITA = true, BAYLEEF = true, MEGANIUM = true,
  CYNDAQUIL = true, QUILAVA = true, TYPHLOSION = true,
  TOTODILE = true, CROCONAW = true, FERALIGATR = true,
}

local function setting(mod, key, default)
  local value = mod.save:get(key)
  if value == nil then return default end
  return value
end

local function isRival(classId)
  return classId == "RIVAL1" or classId == "RIVAL2"
end

function TrainerRandomizer.install(mod)
  local shared = assert(mod.exports.wildRandomizer,
    "wild randomizer must be installed before trainer randomizer")

  local function transform(data, classId, member, party)
    local mode = setting(mod, "trainer_randomizer", "off")
    if mode == "off" or (setting(mod, "trainer_bosses", "include") == "exclude"
        and BOSSES[classId]) then
      return party
    end
    local allowLegendaries = setting(mod, "trainer_legendaries", "exclude")
      == "allow"
    local result = {}
    for index, mon in ipairs(party or {}) do
      if isRival(classId) and RIVAL_STARTERS[mon.species] then
        result[index] = mon
      else
        local replacement = shared.chooseSpecies(data, mon.species, mode,
          table.concat({ "trainer", tostring(classId), tostring(member) }, ":"),
          index, function(species)
            return allowLegendaries or not shared.legendary(species)
          end)
        result[index] = Mon.new(data, replacement, mon.level, {
          item = mon.item, dvs = mon.dvs,
        }) or mon
      end
    end
    return result
  end

  mod.hooks:wrap("trainer.party", function(next, classId, member, party)
    local result = next(classId, member, party) or party
    return transform(mod.game and mod.game.data, classId, member, result)
  end, 1500)

  mod.exports.trainerRandomizer = {
    transform = transform,
    isBoss = function(classId) return BOSSES[classId] == true end,
  }
end

return TrainerRandomizer
