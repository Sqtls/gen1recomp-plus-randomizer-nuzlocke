local StarterRandomizer = {}

local Mon = require("src.battle.gen2.Mon")

local STARTERS = { "CHIKORITA", "CYNDAQUIL", "TOTODILE" }
local STARTER_INDEX = { CHIKORITA = 152, CYNDAQUIL = 155, TOTODILE = 158 }
local STARTER_PROMPTS = {
  ["60:45e3"] = { source = "CYNDAQUIL", prefix = "ELM: You'll take\n" },
  ["60:460e"] = { source = "TOTODILE", prefix = "ELM: Do you want\n" },
  ["60:463a"] = { source = "CHIKORITA", prefix = "ELM: So, you like\n" },
}
local RIVAL_LINE = {
  CHIKORITA = { source = "CHIKORITA", stage = 1 },
  BAYLEEF = { source = "CHIKORITA", stage = 2 },
  MEGANIUM = { source = "CHIKORITA", stage = 3 },
  CYNDAQUIL = { source = "CYNDAQUIL", stage = 1 },
  QUILAVA = { source = "CYNDAQUIL", stage = 2 },
  TYPHLOSION = { source = "CYNDAQUIL", stage = 3 },
  TOTODILE = { source = "TOTODILE", stage = 1 },
  CROCONAW = { source = "TOTODILE", stage = 2 },
  FERALIGATR = { source = "TOTODILE", stage = 3 },
}

local function setting(mod, key, default)
  local value = mod.save:get(key)
  if value == nil then return default end
  return value
end

local function isElmsLab(ctx)
  return type(ctx) == "table" and (ctx.mapId == "ELMS_LAB"
    or ctx.mapId == "24:5"
    or (ctx.mapGroup == 24 and ctx.mapNumber == 5))
end

local function evolvedSpecies(data, species, stage)
  local result = species
  for _ = 2, stage do
    local definition = data and data.pokemon and data.pokemon[result]
    local evolution = definition and definition.evolutions
      and definition.evolutions[1]
    local target = evolution and (evolution.into or evolution.species)
    if not target then break end
    result = target
  end
  return result
end

local function rewriteCommand(cmd, index)
  local result = {}
  for key, value in pairs(cmd or {}) do result[key] = value end
  local source = result.species or result.id
  if result.species ~= nil then result.species = index end
  if result.id ~= nil then result.id = index end
  if result.object == source then result.object = index end
  if type(cmd and cmd.args) == "table" then
    result.args = {}
    for at, value in ipairs(cmd.args) do result.args[at] = value end
    result.args[1] = index
  end
  return result
end

function StarterRandomizer.install(mod)
  local shared = assert(mod.exports.wildRandomizer,
    "wild randomizer must be installed before starter randomizer")

  local function choices(data)
    local mode = setting(mod, "starter_randomizer", "off")
    if mode == "off" then
      return {
        CHIKORITA = "CHIKORITA", CYNDAQUIL = "CYNDAQUIL",
        TOTODILE = "TOTODILE",
      }
    end
    local allowLegendaries = setting(mod, "starter_legendaries", "exclude")
      == "allow"
    local result, used = {}, {}
    for slot, source in ipairs(STARTERS) do
      local replacement = shared.chooseSpecies(data, source, mode,
        "starter:" .. tostring(slot), slot, function(species)
          return not used[species]
            and (allowLegendaries or not shared.legendary(species))
        end)
      result[source] = replacement
      used[replacement] = true
    end
    return result
  end

  local starterOps = {
    pokepic = true, cry = true, getmonname = true, givepoke = true,
    writetext = true,
  }
  mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
    if not starterOps[name] or not isElmsLab(ctx)
        or setting(mod, "starter_randomizer", "off") == "off" then
      return next(ctx, name, args, cmd)
    end
    local source
    local prompt = name == "writetext" and cmd
      and STARTER_PROMPTS[cmd.text]
    if prompt then
      source = prompt.source
    else
      local sourceIndex = name == "cry" and cmd and cmd.id
        or cmd and cmd.species or args and args[1]
      for species, index in pairs(STARTER_INDEX) do
        if index == sourceIndex then source = species break end
      end
    end
    if not source then return next(ctx, name, args, cmd) end
    local data = mod.game and mod.game.data
    local replacement = choices(data)[source]
    local definition = data and data.pokemon and data.pokemon[replacement]
    if not (definition and definition.index) then
      return next(ctx, name, args, cmd)
    end
    if prompt then
      local rewritten = rewriteCommand(cmd, definition.index)
      rewritten.op = "rawtext"
      rewritten.text = prompt.prefix .. (definition.name or replacement) .. "?"
      return next(ctx, "rawtext", {}, rewritten)
    end
    local rewritten = rewriteCommand(cmd, definition.index)
    local rewrittenArgs = args
    if type(args) == "table" and args[1] ~= nil then
      rewrittenArgs = {}
      for at, value in ipairs(args) do rewrittenArgs[at] = value end
      rewrittenArgs[1] = definition.index
    end
    return next(ctx, name, rewrittenArgs, rewritten)
  end, 1000)

  mod.hooks:wrap("trainer.party", function(next, classId, member, party)
    local result = next(classId, member, party) or party
    if setting(mod, "starter_randomizer", "off") == "off"
        or (classId ~= "RIVAL1" and classId ~= "RIVAL2") then
      return result
    end
    local game = mod.game
    local data = game and game.data
    local mapped = choices(data)
    for index, mon in ipairs(result or {}) do
      local line = mon and RIVAL_LINE[mon.species]
      if line then
        local species = evolvedSpecies(data, mapped[line.source], line.stage)
        result[index] = Mon.new(data, species, mon.level, {
          item = mon.item, dvs = mon.dvs,
        }) or mon
      end
    end
    return result
  end, 2000)

  mod.exports.starterRandomizer = { choices = choices }
end

return StarterRandomizer
