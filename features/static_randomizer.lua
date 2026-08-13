local StaticRandomizer = {}

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

local function copyCommand(cmd, speciesIndex)
  local result = {}
  for key, value in pairs(cmd or {}) do result[key] = value end
  result.species = speciesIndex
  if type(cmd and cmd.args) == "table" then
    result.args = {}
    for index, value in ipairs(cmd.args) do result.args[index] = value end
    result.args[1] = speciesIndex
  end
  return result
end

function StaticRandomizer.install(mod)
  local shared = assert(mod.exports.wildRandomizer,
    "wild randomizer must be installed before static randomizer")

  local function choose(data, source, scope)
    local mode = setting(mod, "static_randomizer", "off")
    if mode == "off" then return source end
    local matchLegendaries = setting(mod, "static_legendaries", "match")
      == "match"
    local sourceLegendary = shared.legendary(source)
    return shared.chooseSpecies(data, source, mode, scope, 1,
      function(species)
        return not matchLegendaries
          or shared.legendary(species) == sourceLegendary
      end)
  end

  mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
    if name ~= "loadwildmon" or setting(mod, "static_randomizer", "off")
        == "off" then
      return next(ctx, name, args, cmd)
    end
    local data = mod.game and mod.game.data
    local pokemon = data and data.pokemon
    local sourceIndex = cmd and (cmd.species
      or cmd.args and cmd.args[1]) or args and args[1]
    local source = speciesByIndex(pokemon, sourceIndex)
    if not source then return next(ctx, name, args, cmd) end
    local scriptKey = ctx and ctx.scriptKey
    if type(scriptKey) ~= "string" and type(scriptKey) ~= "number" then
      scriptKey = "inline"
    end
    local scope = table.concat({
      tostring(ctx and ctx.mapId or "UNKNOWN"), tostring(scriptKey),
      tostring(ctx and ctx.object or ""), source,
      tostring(cmd and (cmd.level or cmd.args and cmd.args[2]) or ""),
    }, ":")
    local replacement = choose(data, source, scope)
    local definition = pokemon and pokemon[replacement]
    if not (definition and definition.index) then
      return next(ctx, name, args, cmd)
    end
    local rewritten = copyCommand(cmd, definition.index)
    local rewrittenArgs = args
    if type(args) == "table" and args[1] ~= nil then
      rewrittenArgs = {}
      for index, value in ipairs(args) do rewrittenArgs[index] = value end
      rewrittenArgs[1] = definition.index
    end
    return next(ctx, name, rewrittenArgs, rewritten)
  end, 1000)

  mod.exports.staticRandomizer = { choose = choose }
end

return StaticRandomizer
