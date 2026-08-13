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
        { label = "DONE", value = "done" },
      }
      local function refresh()
        items[1].right = setting(mod, "strict_encounters", true)
          and "ON" or "OFF"
        items[2].right = setting(mod, "dupes_mode", "skip"):upper()
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
    return result
  end)

  mod.events:on("intro.oak_speech.answered", function(ev)
    if ev and (ev.saveKey == "strict_encounters"
        or ev.saveKey == "dupes_mode") then
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

  local function enabled(game)
    return setting(mod, "strict_encounters", true) == true
  end

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

  local function eligibleBattle(battle)
    return type(battle) == "table" and battle.wild == true
      and not battle.tutorial and not battle.contest
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
    if not enabled(game) or not eligibleBattle(battle) then return end

    local key, mapId = canonicalArea(game)
    local existing = ledger()[key]
    battles[battle] = { key = key }
    if existing then return end

    local species = ev.species or battle.enemy and battle.enemy.species
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

  mod.hooks:wrap("battle.catch_allowed", function(next, ctx)
    local game = ctx and ctx.game or mod.game
    local battle = ctx and ctx.battle
    if not enabled(game) or not eligibleBattle(battle) then return next(ctx) end

    local key = canonicalArea(game)
    local state = ledger()[key]
    local current = battles[battle]
    if current and current.duplicate then
      return false, current.duplicate == "lose"
        and "A duplicate encounter\nwas lost for this area!"
        or "This is a duplicate.\nFind a different family!"
    end
    if state and (state.status == "caught" or state.status == "failed"
        or (state.status == "active" and not current)) then
      return false, "This area's encounter\nis no longer available!"
    end
    return next(ctx)
  end, 1000)
end

return StrictEncounters
