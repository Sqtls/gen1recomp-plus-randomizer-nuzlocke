local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local Encounter = {
  treeSet = function() return "FOREST" end,
  treeIsRare = function() return false end,
  treeSlot = function()
    return { species = "RATTATA", level = 6 }
  end,
}
package.loaded[table.concat({ "src", "battle", "gen2", "Encounter" }, ".")] =
  Encounter

local World = {
  rockMonEncounter = function(world)
    world.tempWildMon = { species = 1, level = 8 }
    return 1
  end,
}
package.loaded[table.concat({ "src", "world", "gen2", "World" }, ".")] = World

local hooks = {}
local listeners = {}
local saved = { randomizer_seed = 739391 }
local mod = {
  exports = {},
  hooks = {
    wrap = function(_, name, callback) hooks[name] = callback end,
  },
  events = {
    on = function(_, name, callback) listeners[name] = callback end,
  },
  save = {
    get = function(_, key, default)
      if saved[key] == nil then return default end
      return saved[key]
    end,
    set = function(_, key, value) saved[key] = value end,
  },
}

local function stats(value)
  return {
    hp = value, attack = value, defense = value,
    speed = value, specialAttack = value, specialDefense = value,
  }
end

local pokemon = {
  RATTATA = { index = 1, baseStats = stats(42),
    evolutions = { { into = "RATICATE" } } },
  RATICATE = { index = 2, baseStats = stats(69), evolutions = {} },
  PIDGEY = { index = 3, baseStats = stats(42),
    evolutions = { { into = "PIDGEOTTO" } } },
  PIDGEOTTO = { index = 4, baseStats = stats(58),
    evolutions = { { into = "PIDGEOT" } } },
  PIDGEOT = { index = 5, baseStats = stats(80), evolutions = {} },
  SENTRET = { index = 6, baseStats = stats(41),
    evolutions = { { into = "FURRET" } } },
  FURRET = { index = 7, baseStats = stats(69), evolutions = {} },
  MAGIKARP = { index = 8, baseStats = stats(33),
    evolutions = { { into = "GYARADOS" } } },
  GYARADOS = { index = 9, baseStats = stats(90), evolutions = {} },
  MILTANK = { index = 10, baseStats = stats(82), evolutions = {} },
  LUGIA = { index = 11, baseStats = stats(113), evolutions = {} },
  MEWTWO = { index = 12, baseStats = stats(113), evolutions = {} },
  UNOWN = { index = 13, baseStats = stats(56), evolutions = {} },
}
local data = { pokemon = pokemon }
mod.game = { data = data }

local feature = assert(loadfile(root .. "/features/wild_randomizer.lua"))()
feature.install(mod)
local randomizer = mod.exports.wildRandomizer

local function speciesHook(species, level, ctx)
  return hooks["encounter.species"](function(encounter) return encounter end,
    { species = species, level = level, slot = ctx.slot or 1 }, ctx)
end

saved.wild_randomizer = "off"
local result = speciesHook("RATTATA", 4, {
  kind = "wild", mapId = "ROUTE_29", terrain = "grass",
  daytime = "day", data = data, slot = 1,
})
eq(result.species, "RATTATA", "OFF preserves the vanilla species")
eq(result.level, 4, "OFF preserves the vanilla level")

saved.wild_randomizer = "balanced"
saved.wild_legendaries = "exclude"
result = speciesHook("RATTATA", 4, {
  kind = "wild", mapId = "ROUTE_29", terrain = "grass",
  daytime = "day", data = data, slot = 1,
})
eq(result.species ~= "RATTATA", true,
  "BALANCED replaces a slot when another match exists")
eq(result.species == "PIDGEY" or result.species == "SENTRET", true,
  "BALANCED preserves base-stage role and similar BST")
eq(result.level, 4, "BALANCED does not alter encounter levels")
local repeated = speciesHook("RATTATA", 4, {
  kind = "wild", mapId = "ROUTE_29", terrain = "grass",
  daytime = "day", data = data, slot = 1,
})
eq(repeated.species, result.species,
  "the same seed and encounter slot always map identically")

local contest = speciesHook("RATTATA", 4, {
  kind = "contest", mapId = "NATIONAL_PARK", terrain = "grass",
  daytime = "day", data = data, slot = 1,
})
eq(contest.species, "RATTATA", "Bug Contest species are excluded")
local scripted = speciesHook("RATTATA", 4, {
  kind = "script", mapId = "ROUTE_36", data = data, slot = 1,
})
eq(scripted.species, "RATTATA", "scripted static species are excluded")
local scented = speciesHook("RATTATA", 4, {
  kind = "sweet_scent", mapId = "ROUTE_29", terrain = "grass",
  daytime = "day", data = data, slot = 1,
})
eq(scented.species, result.species,
  "Sweet Scent uses the same randomized table as walking")
saved.wild_randomizer = "chaos"
local unown = speciesHook("UNOWN", 5, {
  kind = "wild", mapId = "RUINS_OF_ALPH", terrain = "cave",
  daytime = "day", data = data, slot = 1,
})
eq(unown.species ~= "UNOWN", true,
  "RUINS on by default randomizes the Ruins of Alph Unown")
saved.randomize_ruins = false
local unownOff = speciesHook("UNOWN", 5, {
  kind = "wild", mapId = "RUINS_OF_ALPH", terrain = "cave",
  daytime = "day", data = data, slot = 1,
})
eq(unownOff.species, "UNOWN", "RUINS off keeps Gold's Unown form gate")
saved.randomize_ruins = nil

for slot = 1, 24 do
  local ordinary = randomizer.choose(data, "RATTATA", "ordinary", slot)
  eq(randomizer.legendary(ordinary), false,
    "EXCLUDE keeps legendaries out of ordinary wild slots")
end
saved.wild_legendaries = "allow"
local foundLegendary = false
for slot = 1, 48 do
  if randomizer.legendary(
      randomizer.choose(data, "RATTATA", "legend-check", slot)) then
    foundLegendary = true
    break
  end
end
eq(foundLegendary, true, "ALLOW permits legendary ordinary wild slots")

local candidates = {
  { species = "RATTATA", level = 10 },
  { species = "PIDGEY", level = 10 },
}
local fishing = hooks["encounter.fishing"](function()
  return { species = "RATTATA", level = 10 }
end, "OLD_ROD", "ROUTE_32", candidates, { data = data })
eq(fishing.species ~= "RATTATA", true, "fishing species are randomized")
eq(fishing.level, 10, "fishing levels remain unchanged")

local encounters = {
  treeSets = {
    FOREST = { common = { { species = "RATTATA", level = 6 } }, rare = {} },
  },
}
local headbutt = Encounter.treeSlot(encounters, "ILEX_FOREST", 1, 1, nil)
eq(headbutt.species ~= "RATTATA", true, "Headbutt species are randomized")
eq(headbutt.level, 6, "Headbutt levels remain unchanged")

local world = {
  game = { data = data }, map = { id = "CIANWOOD_CITY" },
}
local rock = World.rockMonEncounter(world)
eq(rock ~= pokemon.RATTATA.index, true, "Rock Smash species are randomized")
eq(world.tempWildMon.species, rock,
  "Rock Smash stores the replacement species for the scripted battle")
eq(world.tempWildMon.level, 8, "Rock Smash levels remain unchanged")

eq(randomizer.legendary("LUGIA"), true,
  "the legendary classifier includes Lugia")
eq(randomizer.legendary("PIDGEY"), false,
  "the legendary classifier excludes ordinary Pokemon")
saved.randomizer_seed = 0
local previousSeed = saved.randomizer_seed
listeners["save.created"]()
eq(type(saved.randomizer_seed), "number", "new saves receive a numeric seed")
eq(saved.randomizer_seed >= 1 and saved.randomizer_seed <= 2147483646, true,
  "new save seeds stay in the supported range")
eq(saved.randomizer_seed ~= previousSeed, true,
  "creating a save replaces any previous randomizer seed")

-- CHAOS used to add the slot to the hash result rather than hashing it, so
-- consecutive slots of one scope walked consecutive entries of a Pokedex-sorted
-- pool: a trainer's party came out as a single evolution line. Check over a
-- full-size pool that neighbouring slots land no closer than chance would put
-- them, and that the spread across scopes stays even.
local wide = { pokemon = {} }
for index = 1, 251 do
  wide.pokemon["MON_" .. index] = {
    index = index, baseStats = stats(50), evolutions = {},
  }
end
-- The source species is part of the hashed key, and its length decides how far
-- apart two neighbouring slots land, so the sweep has to cover several name
-- lengths. Eight-letter names were the worst case: they scored 88% before the
-- second fold went in.
saved.randomizer_seed = 739391
local buckets, total = {}, 0
for _, sourceName in ipairs({ "MON_1", "MON_40", "MON_150", "MON_249" }) do
  local neighbours, samples = 0, 0
  for map = 1, 200 do
    local scope = "MAP_" .. map .. ":grass:day"
    local previous
    for slot = 1, 6 do
      local picked = randomizer.chooseSpecies(wide, sourceName, "chaos", scope,
        slot)
      local index = wide.pokemon[picked].index
      buckets[index] = (buckets[index] or 0) + 1
      total = total + 1
      if previous then
        samples = samples + 1
        if math.abs(index - previous) <= 2 then neighbours = neighbours + 1 end
      end
      previous = index
    end
  end
  -- Chance over a 251-entry pool is about 2%. Adding the slot scored 100%, and
  -- hashing it without the second fold scored 88% at some name lengths.
  eq(neighbours / samples < 0.10, true,
    "CHAOS slots scatter for source name " .. sourceName)
end
local occupied, busiest = 0, 0
for _, count in pairs(buckets) do
  if count > 0 then occupied = occupied + 1 end
  if count > busiest then busiest = count end
end
eq(occupied > 200, true, "CHAOS spreads across the whole species pool")
-- v0.28.2 collapsed onto pool[1] in game and handed out nothing but Bulbasaur.
eq(busiest < (total / 251) * 4, true,
  "no single species swallows the pool")
local repeatable = randomizer.chooseSpecies(wide, "MON_1", "chaos",
  "MAP_1:grass:day", 1)
eq(repeatable, randomizer.chooseSpecies(wide, "MON_1", "chaos",
  "MAP_1:grass:day", 1), "CHAOS stays deterministic for one seed and slot")

print("wild randomizer: " .. checks .. " checks passed")
