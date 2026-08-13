local StrictEncounters = {}
local SETTINGS_SCREEN = "Gen1RecompPlusNuzlockeSettings"
local TextBox = require("src.render.TextBox")

local function setting(mod, key, default)
  local value = mod.save:get(key)
  if value == nil then return default end
  return value
end

function StrictEncounters.install(mod)
  local started
  mod.content.screens:register(SETTINGS_SCREEN, {
    new = function(game)
      local locked = started(game)
      local items = {
        { label = "1ST ENCOUNTER", value = "strict_encounters" },
        { label = "DUPES", value = "dupes_mode" },
        { label = "SHINY CLAUSE", value = "shiny_clause" },
        { label = "PERMADEATH", value = "permadeath" },
        { label = "MANDATORY NAMES", value = "mandatory_nicknames" },
        { label = "LEVEL CAPS", value = "level_caps" },
        { label = "LEVEL SCALING", value = "level_scaling" },
        { label = "SET MODE", value = "forced_set_mode" },
        { label = "NO BATTLE ITEMS", value = "no_battle_items" },
        { label = "STATIC", value = "static_encounters" },
        { label = "GIFTS", value = "gift_encounters" },
        { label = "BREEDING", value = "breeding_eggs" },
        { label = "WILD MODE", value = "wild_randomizer" },
        { label = "WILD LEG", value = "wild_legendaries" },
        { label = "STATICS", value = "static_randomizer" },
        { label = "STATIC LEG", value = "static_legendaries" },
        { label = "STARTERS", value = "starter_randomizer" },
        { label = "STARTER LEG", value = "starter_legendaries" },
        { label = "SEED", value = "randomizer_seed" },
        { label = "DONE", value = "done" },
      }
      local function refresh()
        items[1].right = setting(mod, "strict_encounters", true)
          and "ON" or "OFF"
        items[2].right = setting(mod, "dupes_mode", "skip"):upper()
        items[3].right = setting(mod, "shiny_clause", true) and "ON" or "OFF"
        items[4].right = setting(mod, "permadeath", true) and "ON" or "OFF"
        items[5].right = setting(mod, "mandatory_nicknames", true)
          and "ON" or "OFF"
        if setting(mod, "level_caps", true) then
          local resolver = mod.exports.levelCaps
          local cap = resolver and resolver.current(game)
          items[6].right = "ON/" .. tostring(cap or "NONE")
        else
          items[6].right = "OFF"
        end
        items[7].right = setting(mod, "level_scaling", true)
          and "ON" or "OFF"
        items[8].right = setting(mod, "forced_set_mode", true)
          and "ON" or "OFF"
        items[9].right = setting(mod, "no_battle_items", false)
          and "ON" or "OFF"
        items[10].right = setting(mod, "static_encounters", "area"):upper()
        items[11].right = setting(mod, "gift_encounters", "bonus"):upper()
        items[12].right = setting(mod, "breeding_eggs", "forbid"):upper()
        items[13].right = setting(mod, "wild_randomizer", "off"):upper()
        items[14].right = setting(mod, "wild_legendaries", "exclude"):upper()
        items[15].right = setting(mod, "static_randomizer", "off"):upper()
        items[16].right = setting(mod, "static_legendaries", "match"):upper()
        items[17].right = setting(mod, "starter_randomizer", "off"):upper()
        items[18].right = setting(mod, "starter_legendaries", "exclude"):upper()
        local randomizer = mod.exports.wildRandomizer
        items[19].right = tostring(randomizer and randomizer.seed() or "-")
      end
      refresh()
      return mod.ui.ListMenu.new(game, "NUZLOCKE SETTINGS", items, {
        wrap = true,
        footer = locked and "LOCKED  B:BACK" or "A:CHANGE  B:BACK",
        onChoose = function(item, menu)
          if item.value == "done" then
            menu:close()
            return
          elseif locked then
            game.stack:push(TextBox.new(game,
              "Rules are locked\nfor this run!"))
            return
          elseif item.value == "strict_encounters" then
            mod.save:set("strict_encounters",
              not setting(mod, "strict_encounters", true))
          elseif item.value == "dupes_mode" then
            local current = setting(mod, "dupes_mode", "skip")
            mod.save:set("dupes_mode",
              ({ skip = "lose", lose = "off", off = "skip" })[current]
                or "skip")
          elseif item.value == "shiny_clause" then
            mod.save:set("shiny_clause",
              not setting(mod, "shiny_clause", true))
          elseif item.value == "permadeath" then
            mod.save:set("permadeath", not setting(mod, "permadeath", true))
          elseif item.value == "mandatory_nicknames" then
            mod.save:set("mandatory_nicknames",
              not setting(mod, "mandatory_nicknames", true))
          elseif item.value == "level_caps" then
            mod.save:set("level_caps", not setting(mod, "level_caps", true))
          elseif item.value == "level_scaling" then
            mod.save:set("level_scaling",
              not setting(mod, "level_scaling", true))
          elseif item.value == "forced_set_mode" then
            local value = not setting(mod, "forced_set_mode", true)
            mod.save:set("forced_set_mode", value)
            local rule = mod.exports.forcedSetMode
            if value and rule then rule.force(game) end
          elseif item.value == "no_battle_items" then
            mod.save:set("no_battle_items",
              not setting(mod, "no_battle_items", false))
          elseif item.value == "static_encounters" then
            local current = setting(mod, "static_encounters", "area")
            mod.save:set("static_encounters",
              ({ area = "bonus", bonus = "forbid", forbid = "area" })[current]
                or "area")
          elseif item.value == "gift_encounters" then
            mod.save:set("gift_encounters",
              setting(mod, "gift_encounters", "bonus") == "bonus"
                and "area" or "bonus")
          elseif item.value == "breeding_eggs" then
            local current = setting(mod, "breeding_eggs", "forbid")
            mod.save:set("breeding_eggs",
              ({ forbid = "area", area = "bonus", bonus = "forbid" })[current]
                or "forbid")
          elseif item.value == "wild_randomizer" then
            local current = setting(mod, "wild_randomizer", "off")
            mod.save:set("wild_randomizer",
              ({ off = "balanced", balanced = "chaos", chaos = "off" })[current]
                or "off")
          elseif item.value == "wild_legendaries" then
            mod.save:set("wild_legendaries",
              setting(mod, "wild_legendaries", "exclude") == "exclude"
                and "allow" or "exclude")
          elseif item.value == "static_randomizer" then
            local current = setting(mod, "static_randomizer", "off")
            mod.save:set("static_randomizer",
              ({ off = "balanced", balanced = "chaos", chaos = "off" })[current]
                or "off")
          elseif item.value == "static_legendaries" then
            mod.save:set("static_legendaries",
              setting(mod, "static_legendaries", "match") == "match"
                and "any" or "match")
          elseif item.value == "starter_randomizer" then
            local current = setting(mod, "starter_randomizer", "off")
            mod.save:set("starter_randomizer",
              ({ off = "balanced", balanced = "chaos", chaos = "off" })[current]
                or "off")
          elseif item.value == "starter_legendaries" then
            mod.save:set("starter_legendaries",
              setting(mod, "starter_legendaries", "exclude") == "exclude"
                and "allow" or "exclude")
          end
          refresh()
        end,
      })
    end,
  })

  mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
    local result = next(steps, speech)
    if type(result) ~= "table" then return result end
    mod.ui.insertStepAfter(result, "oak_welcome", {
      id = "plus_strict_encounters", kind = "choice", pic = "oak",
      saveKey = "strict_encounters", text = "Enforce the first\nencounter in each\narea?",
      choices = { "ON", "OFF" }, values = { true, false },
    })
    mod.ui.insertStepAfter(result, "plus_strict_encounters", {
      id = "plus_dupes_mode", kind = "choice", pic = "oak",
      saveKey = "dupes_mode", text = "When the first one\nis a duplicate?",
      choices = { "SKIP", "LOSE", "OFF" },
      values = { "skip", "lose", "off" },
    })
    mod.ui.insertStepAfter(result, "plus_dupes_mode", {
      id = "plus_shiny_clause", kind = "choice", pic = "oak",
      saveKey = "shiny_clause",
      text = "Allow any shiny\nPOK\195\169MON to be\ncaught?",
      choices = { "ON", "OFF" }, values = { true, false },
    })
    mod.ui.insertStepAfter(result, "plus_shiny_clause", {
      id = "plus_permadeath", kind = "choice", pic = "oak",
      saveKey = "permadeath", text = "Permanently lose\nfainted POK\195\169MON?",
      choices = { "ON", "OFF" }, values = { true, false },
    })
    mod.ui.insertStepAfter(result, "plus_permadeath", {
      id = "plus_mandatory_nicknames", kind = "choice", pic = "oak",
      saveKey = "mandatory_nicknames",
      text = "Require a nickname\nfor every POK\195\169MON?",
      choices = { "ON", "OFF" }, values = { true, false },
    })
    mod.ui.insertStepAfter(result, "plus_mandatory_nicknames", {
      id = "plus_level_caps", kind = "choice", pic = "oak",
      saveKey = "level_caps",
      text = "Cap levels at each\nmajor challenge?",
      choices = { "ON", "OFF" }, values = { true, false },
    })
    mod.ui.insertStepAfter(result, "plus_level_caps", {
      id = "plus_level_scaling", kind = "choice", pic = "oak",
      saveKey = "level_scaling",
      text = "Scale wild POK\195\169MON\nand trainer levels?",
      choices = { "ON", "OFF" }, values = { true, false },
    })
    mod.ui.insertStepAfter(result, "plus_level_scaling", {
      id = "plus_forced_set_mode", kind = "choice", pic = "oak",
      saveKey = "forced_set_mode",
      text = "Always use SET\nbattle mode?",
      choices = { "ON", "OFF" }, values = { true, false },
    })
    mod.ui.insertStepAfter(result, "plus_forced_set_mode", {
      id = "plus_no_battle_items", kind = "choice", pic = "oak",
      saveKey = "no_battle_items",
      text = "Forbid non-BALL\nitems in battle?",
      choices = { "OFF", "ON" }, values = { false, true },
    })
    mod.ui.insertStepAfter(result, "plus_no_battle_items", {
      id = "plus_static_encounters", kind = "choice", pic = "oak",
      saveKey = "static_encounters",
      text = "How should static\nencounters work?",
      choices = { "AREA", "BONUS", "FORBID" },
      values = { "area", "bonus", "forbid" },
    })
    mod.ui.insertStepAfter(result, "plus_static_encounters", {
      id = "plus_gift_encounters", kind = "choice", pic = "oak",
      saveKey = "gift_encounters",
      text = "Should gifts use\ntheir area's catch?",
      choices = { "BONUS", "AREA" }, values = { "bonus", "area" },
    })
    mod.ui.insertStepAfter(result, "plus_gift_encounters", {
      id = "plus_breeding_eggs", kind = "choice", pic = "oak",
      saveKey = "breeding_eggs",
      text = "How should bred\nEGGS work?",
      choices = { "FORBID", "AREA", "BONUS" },
      values = { "forbid", "area", "bonus" },
    })
    mod.ui.insertStepAfter(result, "plus_breeding_eggs", {
      id = "plus_wild_randomizer", kind = "choice", pic = "oak",
      saveKey = "wild_randomizer",
      text = "Randomize ordinary\nwild POK\195\169MON?",
      choices = { "OFF", "BALANCED", "CHAOS" },
      values = { "off", "balanced", "chaos" },
    })
    mod.ui.insertStepAfter(result, "plus_wild_randomizer", {
      id = "plus_wild_legendaries", kind = "choice", pic = "oak",
      saveKey = "wild_legendaries",
      text = "Allow LEGENDARIES\nin ordinary wilds?",
      choices = { "EXCLUDE", "ALLOW" },
      values = { "exclude", "allow" },
    })
    mod.ui.insertStepAfter(result, "plus_wild_legendaries", {
      id = "plus_static_randomizer", kind = "choice", pic = "oak",
      saveKey = "static_randomizer",
      text = "Randomize scripted\nstatic POK\195\169MON?",
      choices = { "OFF", "BALANCED", "CHAOS" },
      values = { "off", "balanced", "chaos" },
    })
    mod.ui.insertStepAfter(result, "plus_static_randomizer", {
      id = "plus_static_legendaries", kind = "choice", pic = "oak",
      saveKey = "static_legendaries",
      text = "Map static LEGENDS\nto LEGENDS only?",
      choices = { "MATCH", "ANY" },
      values = { "match", "any" },
    })
    mod.ui.insertStepAfter(result, "plus_static_legendaries", {
      id = "plus_starter_randomizer", kind = "choice", pic = "oak",
      saveKey = "starter_randomizer",
      text = "Randomize the three\nstarter POK\195\169MON?",
      choices = { "OFF", "BALANCED", "CHAOS" },
      values = { "off", "balanced", "chaos" },
    })
    mod.ui.insertStepAfter(result, "plus_starter_randomizer", {
      id = "plus_starter_legendaries", kind = "choice", pic = "oak",
      saveKey = "starter_legendaries",
      text = "Allow a LEGENDARY\nas a starter?",
      choices = { "EXCLUDE", "ALLOW" },
      values = { "exclude", "allow" },
    })
    return result
  end)

  mod.events:on("intro.oak_speech.answered", function(ev)
    if ev and (ev.saveKey == "strict_encounters"
        or ev.saveKey == "dupes_mode" or ev.saveKey == "shiny_clause"
        or ev.saveKey == "permadeath"
        or ev.saveKey == "mandatory_nicknames"
        or ev.saveKey == "level_caps"
        or ev.saveKey == "level_scaling"
        or ev.saveKey == "forced_set_mode"
        or ev.saveKey == "no_battle_items"
        or ev.saveKey == "static_encounters"
        or ev.saveKey == "gift_encounters"
        or ev.saveKey == "breeding_eggs"
        or ev.saveKey == "wild_randomizer"
        or ev.saveKey == "wild_legendaries"
        or ev.saveKey == "static_randomizer"
        or ev.saveKey == "static_legendaries"
        or ev.saveKey == "starter_randomizer"
        or ev.saveKey == "starter_legendaries") then
      mod.save:set(ev.saveKey, ev.value)
      if ev.saveKey == "forced_set_mode" and ev.value == true then
        local rule = mod.exports.forcedSetMode
        if rule then rule.force(mod.game) end
      end
    end
  end)

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local result = next(game, items)
    if type(result) ~= "table" then return result end
    return mod.ui.insertBefore(result, "SAVE", {
      label = "NUZLOCKE",
      desc = { "Challenge", "settings" },
      onSelect = function(activeGame)
        mod.ui.push(activeGame or game, SETTINGS_SCREEN)
      end,
    })
  end)

  local battles = setmetatable({}, { __mode = "k" })
  local originalShinies = setmetatable({}, { __mode = "k" })
  local activeBattle
  local pendingStatic = false

  mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
    if name == "loadwildmon" then
      pendingStatic = true
    elseif name == "randomwildmon" or name == "loadtrainer" then
      pendingStatic = false
    end
    return next(ctx, name, args, cmd)
  end)

  mod.events:on("script.ended", function()
    pendingStatic = false
  end)

  local function enabled(game)
    return setting(mod, "strict_encounters", true) == true
  end

  started = function(game)
    if mod.save:get("nuzlocke_started") == true then return true end
    local areas = mod.save:get("encounter_areas")
    if type(areas) == "table" then
      for _, area in pairs(areas) do
        if type(area) == "table" and area.status == "caught"
            and area.result ~= "gift" then
          mod.save:set("nuzlocke_started", true)
          return true
        end
      end
    end
    local save = game and game.save
    local items = game and game.data and game.data.items
    for itemId, count in pairs(save and save.inventory or {}) do
      if type(count) == "number" and count > 0 and items and items[itemId]
          and items[itemId].pocket == "BALL" then
        mod.save:set("nuzlocke_started", true)
        return true
      end
    end
    return false
  end

  mod.hooks:wrap("input.step", function(next, game, dt)
    started(game)
    return next(game, dt)
  end, 1000)

  local function canonicalArea(game)
    local current = mod.world:current()
    local mapId = current and current.mapId or "UNKNOWN"
    local maps = game and game.data and game.data.gen2Maps
    local landmark = maps and maps[mapId] and maps[mapId].landmark
    if type(landmark) == "number" and landmark > 0 then
      return "LANDMARK:" .. landmark, mapId
    end
    return "MAP:" .. mapId, mapId
  end

  local function ledger()
    local areas = mod.save:get("encounter_areas")
    if type(areas) ~= "table" then
      areas = {}
      mod.save:set("encounter_areas", areas)
    end
    return areas
  end

  local function writeArea(key, value)
    local areas = ledger()
    areas[key] = value
    mod.save:set("encounter_areas", areas)
  end

  local function pokemonName(game, species)
    local pokemon = game and game.data and game.data.pokemon
    local definition = pokemon and pokemon[species]
    return tostring(definition and definition.name or species or "POK\195\169MON")
      :gsub("_", " ")
  end

  local function eligibleBattle(battle, game, ev)
    local save = game and game.save
    local contest = battle and battle.contest
      or save and save.bugContest and save.bugContest.active == true
    local battleType = ev and ev.battleType or battle and battle.battleType
    return type(battle) == "table" and battle.wild == true
      and not battle.tutorial and battleType ~= 3 and not contest
  end

  local function isShiny(candidate)
    candidate = candidate and (candidate.mon or candidate)
    return candidate ~= nil and candidate.shiny == true
  end

  local function shinyClauseExempts(battle)
    return setting(mod, "shiny_clause", true) == true
      and originalShinies[battle] == true
  end

  local function family(data, species)
    local members = {}
    local pending = { species }
    while #pending > 0 do
      local id = table.remove(pending)
      if id and not members[id] then
        members[id] = true
        local pokemon = data and data.pokemon or {}
        for _, evolution in ipairs((pokemon[id] or {}).evolutions or {}) do
          pending[#pending + 1] = evolution.species
        end
        for parent, definition in pairs(pokemon) do
          for _, evolution in ipairs(definition.evolutions or {}) do
            if evolution.species == id then pending[#pending + 1] = parent end
          end
        end
      end
    end
    return members
  end

  local function ownsFamily(game, species)
    local members = family(game and game.data, species)
    return mod.exports.ownershipHistory.ownsFamily(game, members)
  end

  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    local game = mod.game
    local static = pendingStatic and ev and ev.kind == "wild"
    pendingStatic = false
    if not enabled(game) or not started(game)
        or not eligibleBattle(battle, game, ev) then return end

    activeBattle = battle
    originalShinies[battle] = isShiny(battle.enemy)
    local roaming = tonumber(battle.roaming)
    local key, mapId
    if roaming then
      key = "ROAMER:" .. roaming
      local current = mod.world:current()
      mapId = current and current.mapId or "UNKNOWN"
    else
      key, mapId = canonicalArea(game)
    end
    local existing = ledger()[key]
    local species = ev.species or battle.enemy and battle.enemy.species
    if roaming then
      battles[battle] = {
        key = key, species = species, roaming = roaming,
      }
      if not existing then
        writeArea(key, {
          status = "active", species = species, mapId = mapId,
          category = "roamer", roaming = roaming,
        })
      end
      return
    end
    local staticPolicy = static
      and setting(mod, "static_encounters", "area") or nil
    battles[battle] = {
      key = key, species = species,
      staticArea = staticPolicy == "area",
      staticBonus = staticPolicy == "bonus",
      staticForbid = staticPolicy == "forbid",
    }
    if staticPolicy == "bonus" or staticPolicy == "forbid" then return end
    if not static and shinyClauseExempts(battle) then
      battles[battle] = nil
      return
    end
    if existing then return end

    local mode = setting(mod, "dupes_mode", "skip")
    if mode ~= "off" and ownsFamily(game, species) then
      battles[battle].duplicate = mode
      if mode == "lose" then
        writeArea(key, {
          status = "failed", species = species, mapId = mapId,
          result = "duplicate",
        })
      end
      return
    end
    writeArea(key, {
      status = "active", species = species, mapId = mapId,
    })
  end)

  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    if battle then originalShinies[battle] = nil end
    if activeBattle == battle then activeBattle = nil end
    local record = battle and battles[battle]
    if not record then return end
    battles[battle] = nil
    local current = ledger()[record.key]
    if current and current.status == "active" then
      if record.roaming and (ev.result or battle.outcome) ~= "win" then
        return
      end
      current.status = "failed"
      current.result = ev.result or battle.outcome or "ended"
      writeArea(record.key, current)
    end
  end)

  mod.events:on("pokemon.caught", function(ev)
    local battle = ev and ev.battle
    if battle then originalShinies[battle] = nil end
    if activeBattle == battle then activeBattle = nil end
    local record = battle and battles[battle]
    if not record then return end
    battles[battle] = nil
    local current = ledger()[record.key]
    if current and current.status == "active" then
      current.status = "caught"
      current.species = ev.species or current.species
      current.result = nil
      writeArea(record.key, current)
    end
  end)

  local function captureDenial(game, battle)
    if not enabled(game) or not eligibleBattle(battle, game) then return nil end
    local current = battles[battle]
    if current and current.staticForbid then
      return "Static encounters\ncannot be caught!"
    end
    if current and current.staticBonus then return nil end
    if not (current and (current.staticArea or current.roaming))
        and shinyClauseExempts(battle) then
      return nil
    end
    local key = current and current.key or canonicalArea(game)
    local state = ledger()[key]
    local species = state and state.species or current and current.species
      or battle and battle.enemy and battle.enemy.species
    local name = pokemonName(game, species)
    if current and current.duplicate then
      return current.duplicate == "lose"
        and ("Duplicate %s.\nEncounter failed!"):format(name)
        or ("Duplicate %s.\nCatch refused!"):format(name)
    end
    if state and (state.status == "caught" or state.status == "failed"
        or (state.status == "active" and not current)) then
      if current and current.roaming then
        return state.status == "caught"
          and ("Already caught\n%s!"):format(name)
          or ("%s was defeated.\nRoamer failed!"):format(name)
      end
      if state.status == "caught" then
        return ("Already caught\n%s here!"):format(name)
      elseif state.result == "run" then
        return ("You ran from\n%s here!"):format(name)
      elseif state.result == "fled" then
        return ("%s fled.\nEncounter failed!"):format(name)
      elseif state.result == "lose" then
        return ("Lost to %s.\nEncounter failed!"):format(name)
      elseif state.result == "duplicate" then
        return ("Duplicate %s.\nEncounter failed!"):format(name)
      end
      return ("%s was defeated.\nEncounter failed!"):format(name)
    end
    return nil
  end

  mod.hooks:wrap("battle.catch_allowed", function(next, ctx)
    local game = ctx and ctx.game or mod.game
    local denial = captureDenial(game, ctx and ctx.battle)
    if denial then return false, denial end
    return next(ctx)
  end, 1000)

  -- Gold v0.1.80 has catch.rate but does not call battle.catch_allowed before
  -- spending a ball. Force a failed roll there as a compatibility fallback;
  -- newer builds stop at the pre-throw hook above and never reach this one.
  mod.hooks:wrap("catch.rate", function(next, ball, mon, def, opts)
    local battle = opts and opts.battle or activeBattle
    if captureDenial(mod.game, battle) then return false, 0 end
    return next(ball, mon, def, opts)
  end, 1000)

  -- Gold v0.1.80 has no public hook before a ball is consumed. This narrowly
  -- patches that version's Gold battle screen so denial behaves like the
  -- public battle.catch_allowed seam available in newer builds.
  local useItem = require("src.ui.gen2.BattleState").useItem
  assert(type(useItem) == "function",
    "Gold BattleState.useItem is unavailable; update this mod")
  require("src.ui.gen2.BattleState").useItem = function(screen, itemId, ...)
    local game = screen and screen.game or mod.game
    local items = game and game.data and game.data.items
    local item = items and items[itemId]
    if item and item.pocket == "BALL" then
      local denial = captureDenial(game, screen and screen.battle)
      if denial then
        screen.message = denial
        screen.messageTimer = 48
        screen.phase = "resolving"
        return
      end
    end
    return useItem(screen, itemId, ...)
  end
end

return StrictEncounters
