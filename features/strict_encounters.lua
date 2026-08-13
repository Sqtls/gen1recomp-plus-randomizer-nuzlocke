local StrictEncounters = {}
local SETTINGS_SCREEN = "Gen1RecompPlusNuzlockeSettings"

local function setting(mod, key, default)
  local value = mod.save:get(key)
  if value == nil then return default end
  return value
end

function StrictEncounters.install(mod)
  mod.content.screens:register(SETTINGS_SCREEN, {
    new = function(game)
      local items = {
        { label = "1ST ENCOUNTER", value = "strict_encounters" },
        { label = "DUPES", value = "dupes_mode" },
        { label = "SHINY CLAUSE", value = "shiny_clause" },
        { label = "PERMADEATH", value = "permadeath" },
        { label = "MANDATORY NAMES", value = "mandatory_nicknames" },
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
      end
      refresh()
      return mod.ui.ListMenu.new(game, "NUZLOCKE SETTINGS", items, {
        wrap = true,
        footer = "A:CHANGE  B:BACK",
        onChoose = function(item, menu)
          if item.value == "strict_encounters" then
            mod.save:set("strict_encounters",
              not setting(mod, "strict_encounters", true))
          elseif item.value == "dupes_mode" then
            mod.save:set("dupes_mode",
              setting(mod, "dupes_mode", "skip") == "skip"
                and "lose" or "skip")
          elseif item.value == "shiny_clause" then
            mod.save:set("shiny_clause",
              not setting(mod, "shiny_clause", true))
          elseif item.value == "permadeath" then
            mod.save:set("permadeath", not setting(mod, "permadeath", true))
          elseif item.value == "mandatory_nicknames" then
            mod.save:set("mandatory_nicknames",
              not setting(mod, "mandatory_nicknames", true))
          elseif item.value == "done" then
            menu:close()
            return
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
      choices = { "SKIP", "LOSE" }, values = { "skip", "lose" },
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
    return result
  end)

  mod.events:on("intro.oak_speech.answered", function(ev)
    if ev and (ev.saveKey == "strict_encounters"
        or ev.saveKey == "dupes_mode" or ev.saveKey == "shiny_clause"
        or ev.saveKey == "permadeath"
        or ev.saveKey == "mandatory_nicknames") then
      mod.save:set(ev.saveKey, ev.value)
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

  local function enabled(game)
    return setting(mod, "strict_encounters", true) == true
  end

  local function started(game)
    if mod.save:get("nuzlocke_started") == true then return true end
    local areas = mod.save:get("encounter_areas")
    if type(areas) == "table" then
      for _, area in pairs(areas) do
        if type(area) == "table" and area.status == "caught" then
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
    for _, area in pairs(ledger()) do
      if area.status == "caught" and members[area.species] then return true end
    end
    local save = game and game.save or {}
    for _, mon in ipairs(save.party or {}) do
      if mon and members[mon.species] then return true end
    end
    for _, box in pairs(save.boxes or {}) do
      for _, mon in ipairs(box) do
        if mon and members[mon.species] then return true end
      end
    end
    return false
  end

  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    local game = mod.game
    if not enabled(game) or not started(game)
        or not eligibleBattle(battle, game, ev) then return end

    activeBattle = battle
    originalShinies[battle] = isShiny(battle.enemy)
    if shinyClauseExempts(battle) then return end
    local key, mapId = canonicalArea(game)
    local existing = ledger()[key]
    local species = ev.species or battle.enemy and battle.enemy.species
    battles[battle] = { key = key, species = species }
    if existing then return end

    if ownsFamily(game, species) then
      local mode = setting(mod, "dupes_mode", "skip")
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
    if shinyClauseExempts(battle) then return nil end
    local key = canonicalArea(game)
    local state = ledger()[key]
    local current = battles[battle]
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
