local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local Mon = {
  new = function(_, species, level, opts)
    return { species = species, level = level, item = opts and opts.item,
      dvs = opts and opts.dvs, moves = {} }
  end,
}
package.loaded[table.concat({ "src", "battle", "gen2", "Mon" }, ".")] = Mon
local Encounter = {
  treeSet = function() return "FOREST" end,
  treeIsRare = function() return false end,
  treeSlot = function() return nil end,
}
package.loaded[table.concat({ "src", "battle", "gen2", "Encounter" }, ".")] =
  Encounter
local World = { rockMonEncounter = function() return 0 end }
package.loaded[table.concat({ "src", "world", "gen2", "World" }, ".")] = World

local hooks = {}
local listeners = {}
local saved = { randomizer_seed = 78234 }
local mod = {
  exports = {},
  hooks = { wrap = function(_, name, callback) hooks[name] = callback end },
  events = { on = function(_, name, callback) listeners[name] = callback end },
  save = {
    get = function(_, key, default)
      if saved[key] == nil then return default end
      return saved[key]
    end,
    set = function(_, key, value) saved[key] = value end,
  },
}

local function stats(value)
  return { hp = value, attack = value, defense = value, speed = value,
    specialAttack = value, specialDefense = value }
end
local function pokemon(index, value, into)
  return { index = index, baseStats = stats(value), evolutions = into
    and { { into = into } } or {} }
end

local data = { pokemon = {
  BULBASAUR = pokemon(1, 53, "IVYSAUR"),
  IVYSAUR = pokemon(2, 68, "VENUSAUR"),
  VENUSAUR = pokemon(3, 88),
  CHARMANDER = pokemon(4, 52, "CHARMELEON"),
  CHARMELEON = pokemon(5, 68, "CHARIZARD"),
  CHARIZARD = pokemon(6, 89),
  SQUIRTLE = pokemon(7, 52, "WARTORTLE"),
  WARTORTLE = pokemon(8, 68, "BLASTOISE"),
  BLASTOISE = pokemon(9, 88),
  CHIKORITA = pokemon(152, 53, "BAYLEEF"),
  BAYLEEF = pokemon(153, 68, "MEGANIUM"),
  MEGANIUM = pokemon(154, 88),
  CYNDAQUIL = pokemon(155, 52, "QUILAVA"),
  QUILAVA = pokemon(156, 68, "TYPHLOSION"),
  TYPHLOSION = pokemon(157, 89),
  TOTODILE = pokemon(158, 52, "CROCONAW"),
  CROCONAW = pokemon(159, 68, "FERALIGATR"),
  FERALIGATR = pokemon(160, 89),
  RAIKOU = pokemon(243, 97),
  LUGIA = pokemon(249, 113),
  HO_OH = pokemon(250, 113),
} }
mod.game = { data = data }

local wildFeature = assert(loadfile(root .. "/features/wild_randomizer.lua"))()
wildFeature.install(mod)
local starterFeature =
  assert(loadfile(root .. "/features/starter_randomizer.lua"))()
starterFeature.install(mod)
local starter = mod.exports.starterRandomizer

saved.starter_randomizer = "off"
local choices = starter.choices(data)
eq(choices.CHIKORITA, "CHIKORITA", "OFF preserves Chikorita")
eq(choices.CYNDAQUIL, "CYNDAQUIL", "OFF preserves Cyndaquil")
eq(choices.TOTODILE, "TOTODILE", "OFF preserves Totodile")

saved.starter_randomizer = "balanced"
saved.starter_legendaries = "exclude"
choices = starter.choices(data)
eq(choices.CHIKORITA ~= choices.CYNDAQUIL
    and choices.CHIKORITA ~= choices.TOTODILE
    and choices.CYNDAQUIL ~= choices.TOTODILE, true,
  "BALANCED generates three unique starter choices")
for _, sourceId in ipairs({ "CHIKORITA", "CYNDAQUIL", "TOTODILE" }) do
  local choice = choices[sourceId]
  eq(#(data.pokemon[choice].evolutions or {}) > 0, true,
    "BALANCED preserves the base evolution stage")
  eq(mod.exports.wildRandomizer.legendary(choice), false,
    "BALANCED excludes legendary starters")
end
local repeated = starter.choices(data)
eq(repeated.CHIKORITA, choices.CHIKORITA,
  "starter choices are deterministic for the run")
eq(repeated.CYNDAQUIL, choices.CYNDAQUIL,
  "all deterministic starter slots remain stable")

local function command(cmd, ctx)
  local received
  hooks["script.command"](function(_, _, args, rewritten)
    received = { args = args, cmd = rewritten }
  end, ctx or { mapId = "ELMS_LAB", scriptKey = "60:starter", object = 2 },
  cmd.op, cmd.args or {}, cmd)
  return received
end

local replacement = data.pokemon[choices.CYNDAQUIL].index
local picSource = { op = "pokepic", species = 155, object = 155,
  args = { 155 } }
local pic = command(picSource)
eq(pic.cmd.species, replacement, "starter preview shows the replacement")
eq(pic.cmd.object, replacement, "starter preview metadata stays synchronized")
eq(pic.args[1], replacement, "starter preview operands are rewritten")
eq(picSource.species, 155, "starter preview does not mutate ROM data")
local cry = command({ op = "cry", id = 155 })
eq(cry.cmd.id, replacement, "starter preview plays the replacement cry")
local name = command({ op = "getmonname", species = 155, args = { 155 } })
eq(name.cmd.species, replacement, "starter prompt names the replacement")
local gift = command({ op = "givepoke", species = 155, level = 5,
  item = 173, args = { 155, 5, 173, 0 } })
eq(gift.cmd.species, replacement, "starter grant gives the replacement")
eq(gift.cmd.level, 5, "starter grant preserves level 5")
eq(gift.cmd.item, 173, "starter grant preserves the held Berry")
local elsewhere = command({ op = "givepoke", species = 155, level = 5 },
  { mapId = "GOLDENROD_CITY", scriptKey = "gift" })
eq(elsewhere.cmd.species, 155,
  "nonstarter gifts of an original starter are not randomized")

local rivalSource = {
  { species = "TOTODILE", level = 5, item = "BERRY",
    dvs = { attack = 9 } },
  { species = "ZUBAT", level = 6 },
  { species = "CROCONAW", level = 16 },
  { species = "FERALIGATR", level = 32 },
}
local rival = hooks["trainer.party"](function(_, _, party) return party end,
  "RIVAL1", "RIVAL1_1_TOTODILE", rivalSource)
local rivalBase = choices.TOTODILE
local rivalMiddle = data.pokemon[rivalBase].evolutions[1].into
local rivalFinal = data.pokemon[rivalMiddle].evolutions[1].into
eq(rival[1].species, rivalBase,
  "rival receives the randomized counter-slot starter")
eq(rival[1].level, 5, "rival starter keeps its authored level")
eq(rival[1].item, "BERRY", "rival starter keeps its held item")
eq(rival[2].species, "ZUBAT", "rival nonstarter party members are unchanged")
eq(rival[3].species, rivalMiddle,
  "later rival battles use the replacement's middle evolution")
eq(rival[4].species, rivalFinal,
  "later rival battles use the replacement's final evolution")
local youngster = hooks["trainer.party"](
  function(_, _, party) return party end, "YOUNGSTER", 1, rivalSource)
eq(youngster, rivalSource, "nonrival trainer parties are untouched")

saved.starter_randomizer = "chaos"
saved.starter_legendaries = "exclude"
for seed = 1, 20 do
  saved.randomizer_seed = seed
  local excluded = starter.choices(data)
  for _, species in pairs(excluded) do
    eq(mod.exports.wildRandomizer.legendary(species), false,
      "EXCLUDE prevents legendary chaos starters")
  end
end
saved.starter_legendaries = "allow"
local foundLegendary = false
for seed = 1, 100 do
  saved.randomizer_seed = seed
  for _, species in pairs(starter.choices(data)) do
    if mod.exports.wildRandomizer.legendary(species) then
      foundLegendary = true
      break
    end
  end
  if foundLegendary then break end
end
eq(foundLegendary, true, "ALLOW permits legendary chaos starters")

print("starter randomizer: " .. checks .. " checks passed")
