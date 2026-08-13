local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

package.loaded["src.battle.gen2.Encounter"] = {
  treeSet = function() return "FOREST" end,
  treeIsRare = function() return false end,
  treeSlot = function() return nil end,
}
package.loaded["src.world.gen2.World"] = {
  rockMonEncounter = function() return 0 end,
}

local Mon = {}
function Mon.new(data, species, level, opts)
  local learned = {}
  for _, row in ipairs(data.pokemon[species].levelMoves or {}) do
    if row.level <= level then
      learned[#learned + 1] = { id = row.move, pp = data.moves[row.move].pp }
    end
  end
  while #learned > 4 do table.remove(learned, 1) end
  return {
    species = species, level = level, moves = learned,
    item = opts and opts.item, dvs = opts and opts.dvs,
  }
end
package.loaded["src.battle.gen2.Mon"] = Mon

local function stats(value)
  return { hp = value, attack = value, defense = value, speed = value,
    specialAttack = value, specialDefense = value }
end

local moves = {
  { level = 1, move = "MOVE_A" }, { level = 3, move = "MOVE_B" },
  { level = 5, move = "MOVE_C" }, { level = 7, move = "MOVE_D" },
  { level = 9, move = "MOVE_E" },
}
local function pokemon(index, value, into)
  return { index = index, name = "MON" .. index, baseStats = stats(value),
    evolutions = into and { { into = into } } or {}, levelMoves = moves }
end

local data = { moves = {
  MOVE_A = { pp = 10 }, MOVE_B = { pp = 11 }, MOVE_C = { pp = 12 },
  MOVE_D = { pp = 13 }, MOVE_E = { pp = 14 }, OLD_MOVE = { pp = 5 },
}, pokemon = {
  BULBASAUR = pokemon(1, 53, "IVYSAUR"),
  IVYSAUR = pokemon(2, 68, "VENUSAUR"),
  VENUSAUR = pokemon(3, 88),
  CHARMANDER = pokemon(4, 52, "CHARMELEON"),
  CHARMELEON = pokemon(5, 68, "CHARIZARD"),
  CHARIZARD = pokemon(6, 89),
  RATTATA = pokemon(19, 42),
  SPEAROW = pokemon(21, 44, "FEAROW"),
  FEAROW = pokemon(22, 74),
  PIKACHU = pokemon(25, 53, "RAICHU"),
  RAICHU = pokemon(26, 81),
  PIDGEY = pokemon(16, 42, "PIDGEOTTO"),
  PIDGEOTTO = pokemon(17, 58, "PIDGEOT"),
  PIDGEOT = pokemon(18, 80),
  CHIKORITA = pokemon(152, 53, "BAYLEEF"),
  BAYLEEF = pokemon(153, 68, "MEGANIUM"),
  MEGANIUM = pokemon(154, 88),
  CYNDAQUIL = pokemon(155, 52, "QUILAVA"),
  QUILAVA = pokemon(156, 68, "TYPHLOSION"),
  TYPHLOSION = pokemon(157, 89),
  TOTODILE = pokemon(158, 52, "CROCONAW"),
  CROCONAW = pokemon(159, 68, "FERALIGATR"),
  FERALIGATR = pokemon(160, 89),
  SENTRET = pokemon(161, 36),
  LUGIA = pokemon(249, 113),
  HO_OH = pokemon(250, 113),
} }

local saved = {
  randomizer_seed = 321, trainer_randomizer = "balanced",
  trainer_legendaries = "exclude", trainer_bosses = "include",
}
local hooks = {}
local mod = {
  game = { data = data }, exports = {},
  hooks = { wrap = function(_, name, callback, priority)
    hooks[name] = { callback = callback, priority = priority }
  end },
  events = { on = function() end },
  save = {
    get = function(_, key, default)
      if saved[key] == nil then return default end
      return saved[key]
    end,
    set = function(_, key, value) saved[key] = value end,
  },
}

local wild = assert(loadfile(root .. "/features/wild_randomizer.lua"))()
wild.install(mod)
local trainer = assert(loadfile(root .. "/features/trainer_randomizer.lua"))()
trainer.install(mod)

eq(hooks["trainer.party"].priority, 1500,
  "trainer randomization runs between starter mapping and level scaling")

local function randomize(classId, member, party)
  return hooks["trainer.party"].callback(
    function(_, _, value) return value end, classId, member, party)
end

local dvs = { attack = 9, defense = 8, speed = 8, special = 8 }
local sourceParty = { { species = "PIDGEY", level = 10,
  item = "BERRY", dvs = dvs, moves = { { id = "OLD_MOVE" } } } }
local result = randomize("BIRD_KEEPER", "ABE", sourceParty)
eq(result[1].species ~= "PIDGEY", true,
  "BALANCED replaces an ordinary trainer species")
eq(#data.pokemon[result[1].species].evolutions > 0, true,
  "BALANCED preserves the original evolution stage")
eq(result[1].level, 10, "trainer randomization preserves the incoming level")
eq(result[1].item, "BERRY", "trainer randomization preserves held items")
eq(result[1].dvs, dvs, "trainer randomization preserves fixed trainer DVs")
eq(result[1].moves[1].id, "MOVE_B",
  "replacement learns its first of four latest legal moves")
eq(result[1].moves[4].id, "MOVE_E",
  "replacement learns its fourth latest legal move")
eq(sourceParty[1].species, "PIDGEY", "ROM-derived trainer rows are not mutated")
eq(sourceParty[1].moves[1].id, "OLD_MOVE",
  "authored source moves remain untouched")

local repeated = randomize("BIRD_KEEPER", "ABE", sourceParty)
eq(repeated[1].species, result[1].species,
  "the same trainer and slot remain deterministic")

saved.trainer_randomizer = "off"
eq(randomize("BIRD_KEEPER", "ABE", sourceParty), sourceParty,
  "OFF preserves the complete trainer party")

saved.trainer_randomizer = "chaos"
saved.trainer_bosses = "exclude"
eq(randomize("FALKNER", "FALKNER1", sourceParty), sourceParty,
  "boss exclusion preserves Gym Leader parties")
eq(randomize("RED", "RED1", sourceParty), sourceParty,
  "boss exclusion preserves Red's party")
eq(randomize("BIRD_KEEPER", "ABE", sourceParty)[1].species ~= "PIDGEY", true,
  "boss exclusion still randomizes ordinary trainers")

saved.trainer_bosses = "include"
eq(randomize("FALKNER", "FALKNER1", sourceParty)[1].species ~= "PIDGEY", true,
  "boss inclusion randomizes Gym Leader parties")

local rivalParty = {
  { species = "TOTODILE", level = 5, dvs = dvs },
  { species = "ZUBAT", level = 6, dvs = dvs },
  { species = "CROCONAW", level = 16, dvs = dvs },
}
data.pokemon.ZUBAT = pokemon(41, 41, "GOLBAT")
data.pokemon.GOLBAT = pokemon(42, 76)
local rival = randomize("RIVAL1", "RIVAL1_2_TOTODILE", rivalParty)
eq(rival[1], rivalParty[1],
  "rival base starter remains owned by the starter randomizer")
eq(rival[3], rivalParty[3],
  "rival evolved starter remains owned by the starter randomizer")
eq(rival[2].species ~= "ZUBAT", true,
  "rival nonstarter party members are randomized")

saved.trainer_legendaries = "exclude"
for seed = 1, 30 do
  saved.randomizer_seed = seed
  local excluded = randomize("BIRD_KEEPER", "ABE", sourceParty)[1].species
  eq(mod.exports.wildRandomizer.legendary(excluded), false,
    "EXCLUDE prevents legendary trainer replacements")
end

saved.trainer_legendaries = "allow"
local foundLegendary = false
for seed = 1, 300 do
  saved.randomizer_seed = seed
  local species = randomize("BIRD_KEEPER", "ABE", sourceParty)[1].species
  if mod.exports.wildRandomizer.legendary(species) then
    foundLegendary = true
    break
  end
end
eq(foundLegendary, true, "ALLOW permits legendary trainer replacements")

print(("trainer randomizer: %d checks passed"):format(checks))
