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
  treeSlot = function() return nil end,
}
package.loaded[table.concat({ "src", "battle", "gen2", "Encounter" }, ".")] =
  Encounter
local World = { rockMonEncounter = function() return 0 end }
package.loaded[table.concat({ "src", "world", "gen2", "World" }, ".")] = World

local hooks = {}
local listeners = {}
local saved = { randomizer_seed = 194841, static_encounters = "area" }
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
  DITTO = { index = 132, baseStats = stats(48), evolutions = {} },
  MEWTWO = { index = 150, baseStats = stats(113), evolutions = {} },
  SUDOWOODO = { index = 185, baseStats = stats(68), evolutions = {} },
  MILTANK = { index = 241, baseStats = stats(82), evolutions = {} },
  RAIKOU = { index = 243, baseStats = stats(97), evolutions = {} },
  LUGIA = { index = 249, baseStats = stats(113), evolutions = {} },
  HO_OH = { index = 250, baseStats = stats(113), evolutions = {} },
}
local data = { pokemon = pokemon }
mod.game = { data = data }

local function speciesAt(index)
  for species, definition in pairs(pokemon) do
    if definition.index == index then return species end
  end
end

local wildFeature = assert(loadfile(root .. "/features/wild_randomizer.lua"))()
wildFeature.install(mod)
local staticFeature =
  assert(loadfile(root .. "/features/static_randomizer.lua"))()
staticFeature.install(mod)
local static = mod.exports.staticRandomizer

local function run(cmd, ctx)
  local received
  local result = hooks["script.command"](function(_, _, args, rewritten)
    received = { args = args, cmd = rewritten }
    return "next-result"
  end, ctx or {
    mapId = "WHIRL_ISLAND_LUGIA_CHAMBER",
    scriptKey = "47:41a0", object = 1,
  }, cmd.op, cmd.args or {}, cmd)
  return result, received
end

saved.static_randomizer = "off"
local original = { op = "loadwildmon", species = 249, level = 40 }
local result, received = run(original)
eq(result, "next-result", "OFF preserves the script command result")
eq(received.cmd.species, 249, "OFF preserves Lugia")

saved.static_randomizer = "balanced"
saved.static_legendaries = "match"
result, received = run(original)
local replacement = received.cmd.species
eq(replacement ~= 249, true, "BALANCED replaces Lugia")
eq(replacement == 150 or replacement == 250, true,
  "MATCH maps Lugia to a similar-BST legendary")
eq(received.cmd.level, 40, "static randomization preserves the level")
eq(original.species, 249, "static randomization does not mutate ROM data")
local _, repeated = run(original)
eq(repeated.cmd.species, replacement,
  "the same static encounter maps deterministically")

local ordinary = { op = "loadwildmon", species = 185, level = 20 }
local _, ordinaryResult = run(ordinary, {
  mapId = "ROUTE_36", scriptKey = "44:5770", object = 7,
})
eq(mod.exports.wildRandomizer.legendary("SUDOWOODO"), false,
  "ordinary source fixture is not legendary")
eq(ordinaryResult.cmd.species == 132 or ordinaryResult.cmd.species == 241,
  true, "MATCH keeps nonlegendary statics nonlegendary")

saved.static_randomizer = "chaos"
local _, chaosMatch = run(original)
local chaosSpecies = speciesAt(chaosMatch.cmd.species)
eq(mod.exports.wildRandomizer.legendary(chaosSpecies), true,
  "CHAOS still honors legendary matching")

saved.static_legendaries = "any"
local foundOrdinary = false
for index = 1, 32 do
  local _, anyResult = run(original, {
    mapId = "WHIRL_ISLAND_LUGIA_CHAMBER",
    scriptKey = "test:" .. index, object = 1,
  })
  local species = speciesAt(anyResult.cmd.species)
  if not mod.exports.wildRandomizer.legendary(species) then
    foundOrdinary = true
    break
  end
end
eq(foundOrdinary, true, "ANY permits a legendary static to become ordinary")

saved.static_legendaries = "match"
local argsOnly = { op = "loadwildmon", args = { 249, 40 } }
local _, argsResult = run(argsOnly)
eq(argsResult.cmd.args[1], argsResult.cmd.species,
  "argument-only static commands receive the same replacement")
eq(argsResult.cmd.args[2], 40,
  "argument-only static commands preserve their level")

local nonStatic = { op = "randomwildmon" }
local _, nonStaticResult = run(nonStatic)
eq(nonStaticResult.cmd, nonStatic,
  "randomwildmon encounter-table commands are not static replacements")
local missing = { op = "loadwildmon", species = 255, level = 5 }
local _, missingResult = run(missing)
eq(missingResult.cmd, missing, "unknown species indexes pass through safely")

saved.static_randomizer = "balanced"
saved.static_legendaries = "match"
local exported = static.choose(data, "LUGIA", "exported-static")
eq(mod.exports.wildRandomizer.legendary(exported), true,
  "exported static mapping honors legendary matching")

print("static randomizer: " .. checks .. " checks passed")
