local WildRandomizer = {}

local Encounter = require("src.battle.gen2.Encounter")
local World = require("src.world.gen2.World")

local MAX_SEED = 2147483646
local LEGENDARIES = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true,
  MEW = true, RAIKOU = true, ENTEI = true, SUICUNE = true,
  LUGIA = true, HO_OH = true, CELEBI = true,
}

local function setting(mod, key, default)
  local value = mod.save:get(key)
  if value == nil then return default end
  return value
end

local function hash(seed, value)
  local result = tonumber(seed) or 1
  for index = 1, #value do
    result = (result * 131 + value:byte(index)) % 2147483647
  end
  return result
end

local function bst(definition)
  local stats = definition and definition.baseStats or {}
  return (stats.hp or 0) + (stats.attack or 0) + (stats.defense or 0)
    + (stats.speed or 0) + (stats.specialAttack or stats.special or 0)
    + (stats.specialDefense or stats.special or 0)
end

local function roles(pokemon)
  local parents = {}
  for _, definition in pairs(pokemon or {}) do
    for _, evolution in ipairs(definition.evolutions or {}) do
      parents[evolution.species] = true
    end
  end
  local result = {}
  for species, definition in pairs(pokemon or {}) do
    local parent = parents[species] == true
    local child = #(definition.evolutions or {}) > 0
    result[species] = parent and (child and "middle" or "final")
      or (child and "base" or "single")
  end
  return result
end

local function speciesPool(data, allowLegendaries)
  local pool = {}
  for species, definition in pairs(data and data.pokemon or {}) do
    local index = type(definition) == "table" and definition.index
    if type(index) == "number" and index >= 1 and index <= 251
        and species ~= "UNOWN"
        and (allowLegendaries or not LEGENDARIES[species]) then
      pool[#pool + 1] = species
    end
  end
  table.sort(pool, function(left, right)
    return data.pokemon[left].index < data.pokemon[right].index
  end)
  return pool
end

local function removeSource(pool, source)
  if #pool <= 1 then return pool end
  local result = {}
  for _, species in ipairs(pool) do
    if species ~= source then result[#result + 1] = species end
  end
  return #result > 0 and result or pool
end

function WildRandomizer.install(mod)
  local function seed()
    local value = mod.save:get("randomizer_seed")
    if type(value) == "number" then return value end
    local random = love and love.math and love.math.random or math.random
    value = random(1, MAX_SEED)
    mod.save:set("randomizer_seed", value)
    return value
  end

  local function enabled()
    return setting(mod, "wild_randomizer", "off") ~= "off"
  end

  local function choose(data, source, scope, slot)
    if not enabled() or not (data and data.pokemon and data.pokemon[source]) then
      return source
    end
    -- Gold's Unown form gate assumes every Unown slot is in the Ruins. Keeping
    -- those slots unchanged prevents randomized routes from silently yielding
    -- no encounter before the first puzzle is solved.
    if source == "UNOWN" then return source end
    local allowLegendaries = setting(mod, "wild_legendaries", "exclude")
      == "allow"
    local pool = speciesPool(data, allowLegendaries)
    if #pool == 0 then return source end
    local mode = setting(mod, "wild_randomizer", "off")
    if mode == "chaos" then
      local index = (hash(seed(), scope) + (slot or 1) - 1) % #pool + 1
      if pool[index] == source and #pool > 1 then index = index % #pool + 1 end
      return pool[index] or source
    end
    pool = removeSource(pool, source)
    if mode == "balanced" then
      local sourceDef = data.pokemon[source]
      local sourceBst = bst(sourceDef)
      local roleMap = roles(data.pokemon)
      local sourceRole = roleMap[source]
      local window = math.max(25, math.floor(sourceBst * 0.10 + 0.5))
      local matched = {}
      for _, species in ipairs(pool) do
        local definition = data.pokemon[species]
        if roleMap[species] == sourceRole
            and math.abs(bst(definition) - sourceBst) <= window then
          matched[#matched + 1] = species
        end
      end
      if #matched == 0 then
        for _, species in ipairs(pool) do
          if roleMap[species] == sourceRole then
            matched[#matched + 1] = species
          end
        end
        table.sort(matched, function(left, right)
          local leftDelta = math.abs(bst(data.pokemon[left]) - sourceBst)
          local rightDelta = math.abs(bst(data.pokemon[right]) - sourceBst)
          if leftDelta == rightDelta then
            return data.pokemon[left].index < data.pokemon[right].index
          end
          return leftDelta < rightDelta
        end)
        while #matched > 16 do table.remove(matched) end
      end
      if #matched > 0 then pool = matched end
    end
    local key = table.concat({ scope, tostring(slot or 1), source }, "|")
    local index = hash(seed(), key) % #pool + 1
    return pool[index] or source
  end

  local function transform(encounter, ctx, method)
    if not (encounter and encounter.species) then return encounter end
    local data = ctx and ctx.data or mod.game and mod.game.data
    local daytime = ctx and ctx.daytime or ""
    local terrain = method or ctx and ctx.terrain or "wild"
    local scope = table.concat({
      tostring(ctx and ctx.mapId or "UNKNOWN"), tostring(terrain),
      tostring(daytime),
    }, ":")
    encounter.species = choose(data, encounter.species, scope,
      encounter.slot or 1)
    return encounter
  end

  mod.hooks:wrap("encounter.species", function(next, encounter, ctx)
    local result = next(encounter, ctx)
    if not result or not ctx
        or (ctx.kind ~= "wild" and ctx.kind ~= "sweet_scent") then
      return result
    end
    return transform(result, ctx)
  end, 1000)

  mod.hooks:wrap("encounter.fishing", function(next, rod, mapId, candidates, ctx)
    local result = next(rod, mapId, candidates, ctx)
    if not result then return result end
    local slot = 1
    for index, row in ipairs(candidates or {}) do
      if row.species == result.species and row.level == result.level then
        slot = index
        break
      end
    end
    result.slot = slot
    return transform(result, {
      mapId = mapId, data = ctx and ctx.data,
    }, "fishing:" .. tostring(rod))
  end, 1000)

  local treeSlot = Encounter.treeSlot
  assert(type(treeSlot) == "function",
    "Gold Headbutt randomization is unavailable; update this mod")
  Encounter.treeSlot = function(encounters, mapId, cx, cy, random)
    local result = treeSlot(encounters, mapId, cx, cy, random)
    if not result or not enabled() then return result end
    local setName = Encounter.treeSet(encounters, mapId)
    local set = encounters and encounters.treeSets and encounters.treeSets[setName]
    local rare = Encounter.treeIsRare(cx, cy)
    local list = set and (rare and set.rare or set.common) or {}
    for index, row in ipairs(list) do
      if row.species == result.species and row.level == result.level then
        result.slot = index
        break
      end
    end
    return transform(result, {
      mapId = mapId, data = mod.game and mod.game.data,
    }, "headbutt:" .. tostring(setName) .. ":" .. (rare and "rare" or "common"))
  end

  local rockMonEncounter = World.rockMonEncounter
  assert(type(rockMonEncounter) == "function",
    "Gold Rock Smash randomization is unavailable; update this mod")
  World.rockMonEncounter = function(world, ...)
    local result = rockMonEncounter(world, ...)
    if not enabled() or not result or result == 0 then return result end
    local game = world and world.game or mod.game
    local pokemon = game and game.data and game.data.pokemon
    local source
    for species, definition in pairs(pokemon or {}) do
      if definition.index == result then source = species break end
    end
    if not source then return result end
    local mapId = world and world.map and world.map.id or "UNKNOWN"
    local replacement = choose(game.data, source, mapId .. ":rock_smash", 1)
    local definition = pokemon[replacement]
    if not (definition and definition.index) then return result end
    if world.tempWildMon then world.tempWildMon.species = definition.index end
    return definition.index
  end

  mod.events:on("save.created", function()
    mod.save:set("randomizer_seed", nil)
    seed()
  end)

  mod.exports.wildRandomizer = {
    seed = seed,
    choose = choose,
    legendary = function(species) return LEGENDARIES[species] == true end,
  }
end

return WildRandomizer
