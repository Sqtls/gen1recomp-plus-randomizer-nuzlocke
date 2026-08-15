local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local legacyBattleState = {
  useItem = function(self, itemId)
    self.usedItem = itemId
    self.save.inventory[itemId] = self.save.inventory[itemId] - 1
  end,
  applyPartyItem = function() end,
  finishBattle = function(self)
    if self.onDone then return self.onDone() end
  end,
  askNickname = function() end,
  shiftOfferAllowed = function() return true end,
}
local battleStateModule = table.concat({ "src", "ui", "gen2", "BattleState" }, ".")
package.loaded[battleStateModule] = legacyBattleState
local worldModule = table.concat({ "src", "world", "gen2", "World" }, ".")
package.loaded[worldModule] = {
  load = function() end,
  poisonFaintScript = function() end,
  askYesNo = function() end,
  repelSuppresses = function() return false end,
  rockMonEncounter = function() return 0 end,
  fruitTreeItem = function() return 0 end,
}

local function newMod(savedValues)
  local hookChains = {}
  local hookEntries = {}
  local listeners = {}
  local saveValues = savedValues or {}
  local currentMap = "ROUTE_29"
  local registeredScreens = {}
  local pushed

  local mod = {
    id = "gen1recomp_plus_randomizer_nuzlocke",
    path = root,
    exports = {},
    content = {
      screens = {
        register = function(_, id, factory) registeredScreens[id] = factory end,
      },
    },
    hooks = {
      wrap = function(_, name, callback, priority)
        local entries = hookEntries[name] or {}
        hookEntries[name] = entries
        entries[#entries + 1] = {
          callback = callback, priority = priority or 0,
        }
        table.sort(entries, function(left, right)
          return left.priority > right.priority
        end)
        hookChains[name] = function(vanilla, ...)
          local function run(index, ...)
            local entry = entries[index]
            if not entry then return vanilla(...) end
            return entry.callback(function(...)
              return run(index + 1, ...)
            end, ...)
          end
          return run(1, ...)
        end
      end,
    },
    events = {
      on = function(_, name, callback)
        listeners[name] = listeners[name] or {}
        listeners[name][#listeners[name] + 1] = callback
      end,
    },
    save = {
      get = function(_, key, default)
        if saveValues[key] == nil then return default end
        return saveValues[key]
      end,
      set = function(_, key, value) saveValues[key] = value end,
    },
    world = {
      current = function() return { mapId = currentMap } end,
    },
    ui = {
      insertBefore = function(items, label, item)
        local at = #items + 1
        for i, row in ipairs(items) do
          if row.label == label then at = i break end
        end
        table.insert(items, at, item)
        return items
      end,
      insertStepAfter = function(steps, anchor, step)
        local at = #steps + 1
        for i, row in ipairs(steps) do
          if row.id == anchor then at = i + 1 break end
        end
        table.insert(steps, at, step)
        return steps
      end,
      ListMenu = {
        new = function(game, title, items, opts)
          return { game = game, title = title, items = items, opts = opts,
            index = 1, close = function(self) self.closed = true end }
        end,
      },
      push = function(_, id, opts) pushed = { id = id, opts = opts } end,
    },
  }
  function mod:read(relative)
    local file = assert(io.open(root .. "/" .. relative, "rb"))
    local body = file:read("*a")
    file:close()
    return body
  end

  local harness = {
    hooks = hookChains,
    save = saveValues,
    screens = registeredScreens,
    pushed = function() return pushed end,
    pushedReset = function() pushed = nil end,
    setMap = function(_, mapId) currentMap = mapId end,
    emit = function(_, name, payload)
      for _, callback in ipairs(listeners[name] or {}) do callback(payload) end
    end,
  }
  return mod, harness
end

local mod, h = newMod()
assert(loadfile(root .. "/main.lua"))()(mod)
mod.game = { save = { inventory = {}, party = {} }, data = { items = {} } }

-- A new run plays Gold's intro untouched; the settings screen opens by itself
-- the first time the player spawns in the bedroom.
eq(type(h.hooks["intro.oak_speech.build"]), "nil",
  "Oak's speech is left exactly as Gold ships it")
h:emit("map.entered", { mapId = "PLAYERS_HOUSE_2F", via = "warp" })
eq(h:pushed(), nil, "walking back upstairs does not open the settings screen")
h:emit("map.entered", { mapId = "ROUTE_29", via = "boot" })
eq(h:pushed(), nil, "no other map opens the settings screen")
h:emit("map.entered", { mapId = "PLAYERS_HOUSE_2F", via = "boot" })
eq(h:pushed().id, "Gen1RecompPlusNuzlockeSettings",
  "spawning at home on a new game opens the settings screen")
eq(h.save.settings_prompted, true, "the prompt is recorded on the save")
h.pushedReset()
h:emit("map.entered", { mapId = "PLAYERS_HOUSE_2F", via = "boot" })
eq(h:pushed(), nil, "the settings screen only opens once per run")

-- Defaults the rest of this file exercises, as a configured run would leave
-- them.
h.save.wild_randomizer = "balanced"
h.save.static_randomizer = "balanced"
h.save.starter_randomizer = "balanced"
h.save.gift_randomizer = "balanced"
h.save.trainer_randomizer = "balanced"


local pushedBox
local game = { stack = { push = function(_, screen) pushedBox = screen end } }
local startHook = h.hooks["ui.start_menu.items"]
eq(type(startHook), "function", "active-save settings hook is registered")
local rows = startHook(function(_, items) return items end, game, {
  { label = "POKéMON", value = "pokemon" },
  { label = "SAVE", value = "save" },
})
eq(rows[2].label, "RULESET", "START menu exposes Nuzlocke settings")
rows[2].onSelect(game)
eq(h:pushed().id, "Gen1RecompPlusNuzlockeSettings",
  "START row opens the settings screen")
local settings = h.screens.Gen1RecompPlusNuzlockeSettings.new(game)

-- SELECT explains the hovered rule and every value it can take. Gold's box
-- shows two lines of eighteen columns per page, so no page may exceed that.
eq(type(settings.opts.onSelectKey), "function",
  "SELECT is wired up on the settings screen")
for _, item in ipairs(settings.items) do
  pushedBox = nil
  settings.opts.onSelectKey(item, settings)
  eq(pushedBox ~= nil, true, item.label .. " explains itself on SELECT")
  eq(pushedBox.isTextBox, true, item.label .. " uses Gold's dialogue box")
  eq(#pushedBox.pages > 0, true, item.label .. " help paginates")
  for _, page in ipairs(pushedBox.pages) do
    eq(#page <= 2, true, item.label .. " help page fits two lines")
    for _, line in ipairs(page) do
      eq(#line <= 18, true, item.label .. " help line fits the box: " .. line)
    end
  end
end
eq(settings.opts.footer:match("SEL:INFO") ~= nil, true,
  "the footer advertises SELECT")
-- A longer footer wraps onto a second line that draws over the list rows.
eq(#settings.opts.footer <= 18, true, "the footer stays on one line")

-- The header reads as a second page once the cursor reaches the randomizers.
eq(settings.title, "NUZLOCKE SETTINGS", "the list opens on the rules page")
local function titleAt(index)
  settings.index = index
  settings:update(0)
  return settings.title
end
for index, item in ipairs(settings.items) do
  local expected = "NUZLOCKE SETTINGS"
  if item.value:match("randomizer") or item.value:match("legendaries")
      or item.value == "trainer_bosses" or item.value == "randomize_ruins" then
    expected = "RANDOMIZER SETTINGS"
  end
  eq(titleAt(index), expected, "header for " .. item.label)
end
eq(titleAt(1), "NUZLOCKE SETTINGS", "scrolling back up restores the header")

-- Crossing onto the randomizers turns the page: the row entered sits at the
-- top of the list, and coming back up puts it at the bottom.
local firstRandomizer
for index, item in ipairs(settings.items) do
  if item.value == "wild_randomizer" then firstRandomizer = index break end
end
settings.rows = 7
settings.index = firstRandomizer - 1
settings.title = "NUZLOCKE SETTINGS"
settings.scroll = 0
settings.index = firstRandomizer
settings:update(0)
eq(settings.scroll, firstRandomizer - 1,
  "the first randomizer row starts the page at the top")
settings.index = firstRandomizer - 1
settings:update(0)
eq(settings.scroll, firstRandomizer - 1 - 7,
  "stepping back up puts the rules page's last row at the bottom")
settings.index = 1
settings:update(0)

-- ListMenu draws the label from x=16 and right-aligns the value at x=152: with
-- an 8px glyph that is seventeen columns, so a row needs to stay under it or
-- the value prints on top of its own label.
for _, item in ipairs(settings.items) do
  eq(#item.label + #(item.right or "") <= 16, true,
    "row fits one line: " .. item.label .. " " .. tostring(item.right))
end

eq(settings.items[1].right, "ON", "active settings show strict encounters")
settings.opts.onChoose(settings.items[1], settings)
eq(h.save.strict_encounters, false,
  "active save can disable strict encounters in-game")
settings.opts.onChoose(settings.items[1], settings)
eq(h.save.strict_encounters, true,
  "active save can re-enable strict encounters in-game")
eq(settings.items[2].right, "SKIP", "active settings show duplicate policy")
eq(settings.items[3].right, "ON", "active settings show shiny clause")
settings.opts.onChoose(settings.items[3], settings)
eq(h.save.shiny_clause, false, "active save can disable shiny clause")
settings.opts.onChoose(settings.items[3], settings)
eq(h.save.shiny_clause, true, "active save can re-enable shiny clause")
eq(settings.items[4].right, "ON", "active settings show permadeath")
settings.opts.onChoose(settings.items[4], settings)
eq(h.save.permadeath, false, "active save can disable permadeath in-game")
settings.opts.onChoose(settings.items[4], settings)
eq(h.save.permadeath, true, "active save can re-enable permadeath in-game")
eq(settings.items[5].right, "ON", "active settings show mandatory names")
settings.opts.onChoose(settings.items[5], settings)
eq(h.save.mandatory_nicknames, false,
  "active save can disable mandatory names in-game")
settings.opts.onChoose(settings.items[5], settings)
eq(h.save.mandatory_nicknames, true,
  "active save can re-enable mandatory names in-game")
eq(settings.items[6].right, "ON/9",
  "active settings show enabled state and current cap")
settings.opts.onChoose(settings.items[6], settings)
eq(h.save.level_caps, false, "active save can disable level caps in-game")
eq(settings.items[6].right, "OFF", "disabled level caps show as off")
settings.opts.onChoose(settings.items[6], settings)
eq(h.save.level_caps, true, "active save can re-enable level caps in-game")
eq(settings.items[7].right, "ON", "level scaling defaults to enabled")
settings.opts.onChoose(settings.items[7], settings)
eq(h.save.level_scaling, false,
  "active save can disable level scaling in-game")
eq(settings.items[7].right, "OFF", "disabled level scaling shows as off")
settings.opts.onChoose(settings.items[7], settings)
eq(h.save.level_scaling, true,
  "active save can re-enable level scaling in-game")
eq(settings.items[8].right, "-20%", "wild scaling defaults to 20% below max")
eq(settings.items[9].right, "-20%", "trainer scaling defaults to 20% below max")
settings.opts.onChoose(settings.items[8], settings)
eq(h.save.wild_scaling_percent, 25, "wild scaling steps in fives")
eq(settings.items[8].right, "-25%", "the new wild scaling step is displayed")
eq(settings.items[9].right, "-20%", "trainer scaling is set independently")
for _ = 1, 6 do settings.opts.onChoose(settings.items[9], settings) end
eq(h.save.trainer_scaling_percent, 50, "trainer scaling stops at 50%")
settings.opts.onChoose(settings.items[9], settings)
eq(h.save.trainer_scaling_percent, 0, "trainer scaling wraps back to 0%")
eq(settings.items[9].right, "-0%", "the wrapped trainer step is displayed")
h.save.wild_scaling_percent = nil
h.save.trainer_scaling_percent = nil
eq(settings.items[10].right, "ON", "forced Set mode defaults to enabled")
settings.opts.onChoose(settings.items[10], settings)
eq(h.save.forced_set_mode, false,
  "active save can disable forced Set mode in-game")
eq(settings.items[10].right, "OFF", "disabled forced Set mode shows as off")
settings.opts.onChoose(settings.items[10], settings)
eq(h.save.forced_set_mode, true,
  "active save can re-enable forced Set mode in-game")
eq(settings.items[11].right, "OFF", "no battle items defaults to disabled")
settings.opts.onChoose(settings.items[11], settings)
eq(h.save.no_battle_items, true,
  "active save can forbid non-ball battle items in-game")
eq(settings.items[11].right, "ON", "enabled battle-item rule shows as on")
settings.opts.onChoose(settings.items[11], settings)
eq(h.save.no_battle_items, false,
  "active save can restore non-ball battle items in-game")
eq(settings.items[12].right, "AREA", "static encounters default to area policy")
settings.opts.onChoose(settings.items[12], settings)
eq(h.save.static_encounters, "bonus", "static policy can change to BONUS")
eq(settings.items[12].right, "BONUS", "bonus static policy is displayed")
settings.opts.onChoose(settings.items[12], settings)
eq(h.save.static_encounters, "forbid", "static policy can change to FORBID")
settings.opts.onChoose(settings.items[12], settings)
eq(h.save.static_encounters, "area", "static policy cycles back to AREA")
eq(settings.items[13].right, "BONUS", "gift encounters default to bonus")
settings.opts.onChoose(settings.items[13], settings)
eq(h.save.gift_encounters, "area", "gift policy can change to AREA")
eq(settings.items[13].right, "AREA", "area gift policy is displayed")
settings.opts.onChoose(settings.items[13], settings)
eq(h.save.gift_encounters, "bonus", "gift policy cycles back to BONUS")
eq(settings.items[14].right, "FORBID", "bred Eggs default to forbidden")
settings.opts.onChoose(settings.items[14], settings)
eq(h.save.breeding_eggs, "area", "breeding policy can change to AREA")
eq(settings.items[14].right, "AREA", "AREA breeding policy is displayed")
settings.opts.onChoose(settings.items[14], settings)
eq(h.save.breeding_eggs, "bonus", "breeding policy can change to BONUS")
settings.opts.onChoose(settings.items[14], settings)
eq(h.save.breeding_eggs, "forbid", "breeding policy cycles to FORBID")
eq(settings.items[15].right, "BALANCED",
  "active settings show balanced wild randomization")
settings.opts.onChoose(settings.items[15], settings)
eq(h.save.wild_randomizer, "chaos", "wild randomizer can change to CHAOS")
eq(settings.items[15].right, "CHAOS", "chaos randomizer mode is displayed")
settings.opts.onChoose(settings.items[15], settings)
eq(h.save.wild_randomizer, "off", "wild randomizer can change to OFF")
settings.opts.onChoose(settings.items[15], settings)
eq(h.save.wild_randomizer, "balanced",
  "wild randomizer cycles back to BALANCED")
eq(settings.items[16].right, "EXCLUDE",
  "ordinary wild legendaries default to excluded")
settings.opts.onChoose(settings.items[16], settings)
eq(h.save.wild_legendaries, "allow",
  "ordinary wild legendaries can be allowed")
eq(settings.items[16].right, "ALLOW",
  "allowed ordinary wild legendaries are displayed")
settings.opts.onChoose(settings.items[16], settings)
eq(h.save.wild_legendaries, "exclude",
  "ordinary wild legendary policy cycles to EXCLUDE")
eq(settings.items[17].right, "BALANCED",
  "active settings show balanced static randomization")
settings.opts.onChoose(settings.items[17], settings)
eq(h.save.static_randomizer, "chaos", "static randomizer can change to CHAOS")
eq(settings.items[17].right, "CHAOS", "chaos static mode is displayed")
settings.opts.onChoose(settings.items[17], settings)
eq(h.save.static_randomizer, "off", "static randomizer can change to OFF")
settings.opts.onChoose(settings.items[17], settings)
eq(h.save.static_randomizer, "balanced",
  "static randomizer cycles back to BALANCED")
eq(settings.items[18].right, "MATCH",
  "static legendaries default to matched mapping")
settings.opts.onChoose(settings.items[18], settings)
eq(h.save.static_legendaries, "any",
  "static legendary mapping can be unrestricted")
eq(settings.items[18].right, "ANY",
  "unrestricted static legendary mapping is displayed")
settings.opts.onChoose(settings.items[18], settings)
eq(h.save.static_legendaries, "match",
  "static legendary mapping cycles to MATCH")
eq(settings.items[19].right, "BALANCED",
  "active settings show balanced starter randomization")
settings.opts.onChoose(settings.items[19], settings)
eq(h.save.starter_randomizer, "chaos",
  "starter randomizer can change to CHAOS")
eq(settings.items[19].right, "CHAOS", "chaos starter mode is displayed")
settings.opts.onChoose(settings.items[19], settings)
eq(h.save.starter_randomizer, "off", "starter randomizer can change to OFF")
settings.opts.onChoose(settings.items[19], settings)
eq(h.save.starter_randomizer, "balanced",
  "starter randomizer cycles back to BALANCED")
eq(settings.items[20].right, "EXCLUDE",
  "legendary starters default to excluded")
settings.opts.onChoose(settings.items[20], settings)
eq(h.save.starter_legendaries, "allow",
  "legendary starters can be allowed")
eq(settings.items[20].right, "ALLOW",
  "allowed legendary starters are displayed")
settings.opts.onChoose(settings.items[20], settings)
eq(h.save.starter_legendaries, "exclude",
  "starter legendary policy cycles to EXCLUDE")
eq(settings.items[21].right, "BALANCED",
  "active settings show balanced gift randomization")
settings.opts.onChoose(settings.items[21], settings)
eq(h.save.gift_randomizer, "chaos",
  "gift randomizer can change to CHAOS")
eq(settings.items[21].right, "CHAOS", "chaos gift mode is displayed")
settings.opts.onChoose(settings.items[21], settings)
eq(h.save.gift_randomizer, "off", "gift randomizer can change to OFF")
settings.opts.onChoose(settings.items[21], settings)
eq(h.save.gift_randomizer, "balanced",
  "gift randomizer cycles back to BALANCED")
eq(settings.items[22].right, "EXCLUDE",
  "legendary gifts default to excluded")
settings.opts.onChoose(settings.items[22], settings)
eq(h.save.gift_legendaries, "allow",
  "legendary gifts can be allowed")
eq(settings.items[22].right, "ALLOW",
  "allowed legendary gifts are displayed")
settings.opts.onChoose(settings.items[22], settings)
eq(h.save.gift_legendaries, "exclude",
  "gift legendary policy cycles to EXCLUDE")
eq(settings.items[23].right, "BALANCED",
  "active settings show balanced trainer randomization")
settings.opts.onChoose(settings.items[23], settings)
eq(h.save.trainer_randomizer, "chaos",
  "trainer randomizer can change to CHAOS")
eq(settings.items[23].right, "CHAOS", "chaos trainer mode is displayed")
settings.opts.onChoose(settings.items[23], settings)
eq(h.save.trainer_randomizer, "off", "trainer randomizer can change to OFF")
settings.opts.onChoose(settings.items[23], settings)
eq(h.save.trainer_randomizer, "balanced",
  "trainer randomizer cycles back to BALANCED")
eq(settings.items[24].right, "EXCLUDE",
  "legendary trainer Pokemon default to excluded")
settings.opts.onChoose(settings.items[24], settings)
eq(h.save.trainer_legendaries, "allow",
  "legendary trainer Pokemon can be allowed")
eq(settings.items[24].right, "ALLOW",
  "allowed trainer legendaries are displayed")
settings.opts.onChoose(settings.items[24], settings)
eq(h.save.trainer_legendaries, "exclude",
  "trainer legendary policy cycles to EXCLUDE")
eq(settings.items[25].right, "INCLUDE",
  "boss teams default to included")
settings.opts.onChoose(settings.items[25], settings)
eq(h.save.trainer_bosses, "exclude", "boss teams can be excluded")
eq(settings.items[25].right, "EXCLUDE",
  "excluded boss teams are displayed")
settings.opts.onChoose(settings.items[25], settings)
eq(h.save.trainer_bosses, "include",
  "boss policy cycles back to INCLUDE")
settings.opts.onChoose(settings.items[26], settings)
eq(h.save.item_randomizer, "balanced", "found items can be randomized")
eq(settings.items[26].right, "BALANCED", "balanced item mode is displayed")
settings.opts.onChoose(settings.items[26], settings)
eq(h.save.item_randomizer, "chaos", "item mode cycles to CHAOS")
settings.opts.onChoose(settings.items[26], settings)
eq(h.save.item_randomizer, "off", "item mode cycles back to OFF")
local visibleSeed = tonumber(settings.items[27].right)
eq(type(visibleSeed), "number", "active settings show the randomizer seed")
settings.opts.onChoose(settings.items[27], settings)
eq(tonumber(settings.items[27].right), visibleSeed,
  "the displayed seed is read-only")

-- Knocking out the first eligible encounter burns the whole named area. Maps
-- which share Gold's native landmark are one area even when their map ids differ.
game.save = { party = {}, boxes = {}, inventory = {} }
game.data = {
  items = {
    POTION = { pocket = "ITEM" },
    POKE_BALL = { pocket = "BALL" },
    FAST_BALL = { pocket = "BALL" },
  },
  gen2Maps = {
    ROUTE_29 = { landmark = 16 },
    ROUTE_29_GATE = { landmark = 16 },
    ROUTE_30 = { landmark = 17 },
    ROUTE_31 = { landmark = 18 },
    ROUTE_32 = { landmark = 19 },
    ROUTE_33 = { landmark = 20 },
    ROUTE_34 = { landmark = 21 },
    ROUTE_35 = { landmark = 22 },
    ROUTE_36 = { landmark = 23 },
    ROUTE_37 = { landmark = 24 },
    ROUTE_38 = { landmark = 25 },
    ROUTE_39 = { landmark = 26 },
    ROUTE_40 = { landmark = 27 },
  },
  pokemon = {
    SENTRET = { evolutions = { { species = "FURRET" } } },
    FURRET = { evolutions = {} },
    HOOTHOOT = { evolutions = { { species = "NOCTOWL" } } },
    NOCTOWL = { evolutions = {} },
    ABRA = { evolutions = { { species = "KADABRA" } } },
    KADABRA = { evolutions = { { species = "ALAKAZAM" } } },
    ALAKAZAM = { evolutions = {} },
    -- Gold's extractor names an evolution target `into`, and TYROGUE branches
    -- into three by stat comparison. Both details must feed family detection.
    TYROGUE = {
      evolutions = {
        { method = "EVOLVE_STAT", into = "HITMONLEE" },
        { method = "EVOLVE_STAT", into = "HITMONCHAN" },
        { method = "EVOLVE_STAT", into = "HITMONTOP" },
      },
    },
    HITMONLEE = { evolutions = {} },
    HITMONCHAN = { evolutions = {} },
    HITMONTOP = { evolutions = {} },
    RATTATA = { evolutions = { { method = "EVOLVE_LEVEL", into = "RATICATE" } } },
    RATICATE = { evolutions = {} },
  },
}
mod.game = game
local beforeBalls = { wild = true, enemy = { species = "SENTRET" } }
h:emit("battle.started", {
  battle = beforeBalls, kind = "wild", species = "SENTRET",
})
h:emit("battle.ended", { battle = beforeBalls, result = "run" })
eq(h.save.encounter_areas and h.save.encounter_areas["LANDMARK:16"], nil,
  "encounters before receiving any Ball do not count")
local stepHook = h.hooks["input.step"]
eq(type(stepHook), "function", "Ball acquisition watcher is registered")
game.save.inventory.POTION = 1
stepHook(function() end, game, 1 / 60)
eq(h.save.nuzlocke_started, nil,
  "receiving a non-Ball item does not start the Nuzlocke")
game.save.inventory.FAST_BALL = 1
stepHook(function() end, game, 1 / 60)
eq(h.save.nuzlocke_started, true,
  "receiving any Ball permanently starts the Nuzlocke")
game.save.inventory.FAST_BALL = nil

local lockedMessage
game.stack = {
  push = function(_, screen) lockedMessage = screen end,
}
local lockedSettings = h.screens.Gen1RecompPlusNuzlockeSettings.new(game)
eq(lockedSettings.opts.footer, "LOCKED SEL:INFO",
  "active-run settings clearly show that rules are locked")
local strictBeforeLockAttempt = h.save.strict_encounters
lockedSettings.opts.onChoose(lockedSettings.items[1], lockedSettings)
eq(h.save.strict_encounters, strictBeforeLockAttempt,
  "active-run settings cannot change a configured rule")
eq(lockedMessage.pages[1][1], "Rules are locked",
  "a locked rule attempt explains why it was refused")
eq(lockedMessage.pages[1][2], "for this run!",
  "the lock refusal applies to the complete run")

-- Roaming slots are persistent encounters of their own. Their species may be
-- randomized later, so identity comes from battle.roaming rather than a list.
local catchHook = h.hooks["battle.catch_allowed"]
eq(type(catchHook), "function", "catch enforcement hook is registered")
local roamer = {
  wild = true, roaming = 1,
  enemy = { species = "RAIKOU" },
}
h:emit("battle.started", {
  battle = roamer, kind = "wild", species = "RAIKOU",
})
eq(h.save.encounter_areas["ROAMER:1"].status, "active",
  "first roaming meeting starts its slot encounter")
eq(h.save.encounter_areas["ROAMER:1"].category, "roamer",
  "roaming record retains its special category")
eq(h.save.encounter_areas["LANDMARK:16"], nil,
  "roamer does not consume the route where it appears")
local allowed = catchHook(function() return true end, {
  game = game, battle = roamer, species = "RAIKOU",
})
eq(allowed, true, "first roaming meeting may use a ball")
h:emit("battle.ended", { battle = roamer, result = "fled" })
eq(h.save.encounter_areas["ROAMER:1"].status, "active",
  "natural roamer flee keeps its slot encounter active")

h:setMap("ROUTE_30")
local roamerAgain = {
  wild = true, roaming = 1,
  enemy = { species = "RAIKOU" },
}
h:emit("battle.started", {
  battle = roamerAgain, kind = "wild", species = "RAIKOU",
})
allowed = catchHook(function() return true end, {
  game = game, battle = roamerAgain, species = "RAIKOU",
})
eq(allowed, true, "same roamer remains catchable on a later route")
h:emit("battle.ended", { battle = roamerAgain, result = "run" })
eq(h.save.encounter_areas["ROAMER:1"].status, "active",
  "running from a roamer keeps its slot encounter active")
eq(h.save.encounter_areas["LANDMARK:17"], nil,
  "later roaming meeting also preserves its route")

h:setMap("ROUTE_31")
local caughtRoamer = {
  wild = true, roaming = 1,
  enemy = { species = "RAIKOU" },
}
h:emit("battle.started", {
  battle = caughtRoamer, kind = "wild", species = "RAIKOU",
})
h:emit("pokemon.caught", {
  game = game, battle = caughtRoamer, species = "RAIKOU",
})
eq(h.save.encounter_areas["ROAMER:1"].status, "caught",
  "catching a roamer completes only its roaming slot")
eq(h.save.encounter_areas["LANDMARK:18"], nil,
  "catching a roamer leaves the current route available")

h:setMap("ROUTE_29")
local defeatedRoamer = {
  wild = true, roaming = 2,
  enemy = { species = "SENTRET" },
}
h:emit("battle.started", {
  battle = defeatedRoamer, kind = "wild", species = "SENTRET",
})
h:emit("battle.ended", { battle = defeatedRoamer, result = "win" })
eq(h.save.encounter_areas["ROAMER:2"].status, "failed",
  "defeating a roamer permanently fails its roaming slot")
eq(h.save.encounter_areas["LANDMARK:16"], nil,
  "defeating a roamer does not fail the route")

local failedRoamer = {
  wild = true, roaming = 2,
  enemy = { species = "SENTRET" },
}
h:emit("battle.started", {
  battle = failedRoamer, kind = "wild", species = "SENTRET",
})
local denial
allowed, denial = catchHook(function() return true end, {
  game = game, battle = failedRoamer, species = "SENTRET",
})
eq(allowed, false, "failed roaming slot cannot be caught later")
eq(denial, "SENTRET was defeated.\nRoamer failed!",
  "failed roaming slot has a dedicated refusal")
h:emit("battle.ended", { battle = failedRoamer, result = "fled" })

local duplicateSpeciesRoamer = {
  wild = true, roaming = 3,
  enemy = { species = "RAIKOU" },
}
h:emit("battle.started", {
  battle = duplicateSpeciesRoamer, kind = "wild", species = "RAIKOU",
})
allowed = catchHook(function() return true end, {
  game = game, battle = duplicateSpeciesRoamer, species = "RAIKOU",
})
eq(allowed, true,
  "a different roaming slot is independent even with the same species")
h:emit("battle.ended", { battle = duplicateSpeciesRoamer, result = "fled" })

local first = { wild = true, enemy = { species = "SENTRET" } }
h:emit("battle.started", { battle = first, kind = "wild", species = "SENTRET" })
eq(h.save.encounter_areas["LANDMARK:16"].status, "active",
  "first encounter reserves its canonical area")
h:emit("battle.ended", { battle = first, result = "win" })
eq(h.save.encounter_areas["LANDMARK:16"].status, "failed",
  "knocking out the encounter permanently fails the area")
h:setMap("ROUTE_29_GATE")
local roamerOnFailedRoute = {
  wild = true, roaming = 3,
  enemy = { species = "RAIKOU" },
}
h:emit("battle.started", {
  battle = roamerOnFailedRoute, kind = "wild", species = "RAIKOU",
})
allowed = catchHook(function() return true end, {
  game = game, battle = roamerOnFailedRoute, species = "RAIKOU",
})
eq(allowed, true, "active roamer bypasses a failed route")
h:emit("battle.ended", { battle = roamerOnFailedRoute, result = "lose" })
eq(h.save.encounter_areas["ROAMER:3"].status, "active",
  "losing to a roamer leaves its persistent encounter active")
eq(h.save.encounter_areas["LANDMARK:16"].status, "failed",
  "roamer does not alter the failed route it appeared on")
local delegated = false
allowed, denial = catchHook(function()
  delegated = true
  return true
end, { game = game, battle = { wild = true }, species = "SENTRET" })
eq(allowed, false, "later catches in the failed area are blocked")
eq(delegated, false, "blocked catch does not consume a ball or turn")
eq(denial, "SENTRET was defeated.\nEncounter failed!",
  "blocked catch explains which encounter was defeated")
local shinyOnFailedRoute = {
  wild = true,
  enemy = { species = "HOOTHOOT", shiny = true },
}
h:emit("battle.started", {
  battle = shinyOnFailedRoute, kind = "wild", species = "HOOTHOOT",
})
allowed = catchHook(function() return true end, {
  game = game, battle = shinyOnFailedRoute, species = "HOOTHOOT",
})
eq(allowed, true, "shiny bypasses an already-failed route")
h:emit("battle.ended", { battle = shinyOnFailedRoute, result = "run" })
eq(h.save.encounter_areas["LANDMARK:16"].status, "failed",
  "shiny encounter does not repair or replace a failed route record")

-- A failed ball keeps the same encounter alive; only a successful catch seals
-- the area as caught and blocks future battles there.
h:setMap("ROUTE_30")
local catchBattle = { wild = true, enemy = { species = "SENTRET" } }
h:emit("battle.started", {
  battle = catchBattle, kind = "wild", species = "SENTRET",
})
delegated = false
allowed = catchHook(function()
  delegated = true
  return true
end, { game = game, battle = catchBattle, species = "SENTRET" })
eq(allowed, true, "first encounter may use a ball")
eq(delegated, true, "allowed throw follows Gold's normal ball path")
eq(h.save.encounter_areas["LANDMARK:17"].status, "active",
  "failed ball does not burn the route while battle continues")
local validScreen = {
  game = game,
  save = { inventory = { POKE_BALL = 2 } },
  battle = catchBattle,
  phase = "menu",
}
legacyBattleState.useItem(validScreen, "POKE_BALL")
eq(validScreen.save.inventory.POKE_BALL, 1,
  "valid first encounter reaches Gold's original ball path")
eq(validScreen.usedItem, "POKE_BALL",
  "valid first encounter is not refused by the compatibility gate")
local rateHook = h.hooks["catch.rate"]
eq(type(rateHook), "function", "Gold v0.1.80 catch fallback is registered")
delegated = false
local caught, rate = rateHook(function()
  delegated = true
  return false, 42
end, "POKE_BALL", catchBattle.enemy, nil, {})
eq(caught, false, "first encounter preserves Gold's normal catch result")
eq(rate, 42, "first encounter preserves Gold's calculated catch rate")
eq(delegated, true, "first encounter delegates through catch.rate")
h:emit("pokemon.caught", {
  game = game, battle = catchBattle, species = "SENTRET",
})
eq(h.save.encounter_areas["LANDMARK:17"].status, "caught",
  "successful catch permanently seals the area")
local blockedBattle = { wild = true, enemy = { species = "HOOTHOOT" } }
h:emit("battle.started", {
  battle = blockedBattle, kind = "wild", species = "HOOTHOOT",
})
delegated = false
caught, rate = rateHook(function()
  delegated = true
  return true, 255
end, "MASTER_BALL", blockedBattle.enemy, nil, {})
eq(caught, false, "Gold v0.1.80 cannot catch again in a sealed area")
eq(rate, 0, "blocked v0.1.80 catch is forced to fail")
eq(delegated, false, "blocked v0.1.80 catch bypasses the vanilla roll")
local blockedScreen = {
  game = game,
  save = { inventory = { POKE_BALL = 2 } },
  battle = blockedBattle,
  phase = "menu",
}
legacyBattleState.useItem(blockedScreen, "POKE_BALL")
eq(blockedScreen.save.inventory.POKE_BALL, 2,
  "Gold v0.1.80 refuses a blocked ball without consuming it")
eq(blockedScreen.usedItem, nil,
  "Gold v0.1.80 returns before the vanilla ball path")
eq(blockedScreen.message, "Already caught\nSENTRET here!",
  "blocked ball explains the recorded catch")
h:emit("battle.ended", { battle = blockedBattle, result = "run" })

local shinyOnCaughtRoute = {
  wild = true,
  enemy = { species = "HOOTHOOT", shiny = true },
}
h:emit("battle.started", {
  battle = shinyOnCaughtRoute, kind = "wild", species = "HOOTHOOT",
})
shinyOnCaughtRoute.enemy.shiny = false
delegated = false
allowed = catchHook(function()
  delegated = true
  return true
end, { game = game, battle = shinyOnCaughtRoute, species = "HOOTHOOT" })
eq(allowed, true, "original shiny bypasses a route after Transform changes it")
eq(delegated, true, "shiny catch delegates to Gold's normal ball path")
eq(h.save.encounter_areas["LANDMARK:17"].species, "SENTRET",
  "shiny encounter does not replace the route's normal catch record")
delegated = false
caught, rate = rateHook(function()
  delegated = true
  return false, 77
end, "FAST_BALL", shinyOnCaughtRoute.enemy, nil,
  { battle = shinyOnCaughtRoute })
eq(rate, 77, "shiny preserves Gold v0.1.80's calculated catch rate")
eq(delegated, true, "shiny bypasses the v0.1.80 catch-rate denial")
local shinyScreen = {
  game = game,
  save = { inventory = { FAST_BALL = 2 } },
  battle = shinyOnCaughtRoute,
  phase = "menu",
}
legacyBattleState.useItem(shinyScreen, "FAST_BALL")
eq(shinyScreen.save.inventory.FAST_BALL, 1,
  "v0.1.80 allows a ball to be thrown at the shiny")
eq(shinyScreen.usedItem, "FAST_BALL",
  "shiny reaches the original v0.1.80 item-use path")
settings.opts.onChoose(settings.items[3], settings)
allowed = catchHook(function() return true end, {
  game = game, battle = shinyOnCaughtRoute, species = "HOOTHOOT",
})
eq(allowed, false, "disabled shiny clause restores the route limit")
settings.opts.onChoose(settings.items[3], settings)
allowed = catchHook(function() return true end, {
  game = game, battle = shinyOnCaughtRoute, species = "HOOTHOOT",
})
eq(allowed, true, "re-enabled shiny clause immediately restores exemption")
h:emit("battle.ended", { battle = shinyOnCaughtRoute, result = "run" })
eq(h.save.encounter_areas["LANDMARK:17"].status, "caught",
  "leaving a shiny encounter does not alter the used route")

local transformedNormal = {
  wild = true,
  enemy = { species = "DITTO", shiny = false },
}
h:emit("battle.started", {
  battle = transformedNormal, kind = "wild", species = "DITTO",
})
transformedNormal.enemy.shiny = true
allowed = catchHook(function() return true end, {
  game = game, battle = transformedNormal, species = "DITTO",
})
eq(allowed, false,
  "normal encounter cannot gain shiny exemption by Transforming")
h:emit("battle.ended", { battle = transformedNormal, result = "run" })

-- Scripted loadwildmon battles are static regardless of species. Their policy
-- takes precedence over the shiny clause so Red Gyarados does not silently
-- become a bonus encounter when AREA or FORBID is selected.
local scriptCommand = h.hooks["script.command"]
eq(type(scriptCommand), "function", "static origin detection is registered")
local function armStatic()
  scriptCommand(function() end, { generation = 2 }, "loadwildmon", {}, {
    op = "loadwildmon", species = "GYARADOS", level = 30,
  })
end

h:setMap("ROUTE_39")
h.save.static_encounters = "area"
armStatic()
local areaStatic = {
  wild = true, enemy = { species = "GYARADOS", shiny = true },
}
h:emit("battle.started", {
  battle = areaStatic, kind = "wild", species = "GYARADOS",
})
eq(h.save.encounter_areas["LANDMARK:26"].status, "active",
  "AREA makes even a shiny static the area's encounter")
h:emit("pokemon.caught", {
  game = game, battle = areaStatic, species = "GYARADOS",
})
eq(h.save.encounter_areas["LANDMARK:26"].status, "caught",
  "AREA static catch consumes its area")
h:emit("battle.ended", { battle = areaStatic, result = "caught" })
armStatic()
local blockedAreaStatic = {
  wild = true, enemy = { species = "GYARADOS", shiny = true },
}
h:emit("battle.started", {
  battle = blockedAreaStatic, kind = "wild", species = "GYARADOS",
})
allowed = catchHook(function() return true end, {
  game = game, battle = blockedAreaStatic, species = "GYARADOS",
})
eq(allowed, false, "AREA blocks a static when its area is already consumed")
h:emit("battle.ended", { battle = blockedAreaStatic, result = "run" })
h.save.encounter_areas["LANDMARK:26"] = nil

h:setMap("ROUTE_38")
h.save.static_encounters = "bonus"
h.save.encounter_areas["LANDMARK:25"] = {
  status = "caught", species = "SENTRET", mapId = "ROUTE_38",
}
armStatic()
local bonusStatic = { wild = true, enemy = { species = "SNORLAX" } }
h:emit("battle.started", {
  battle = bonusStatic, kind = "wild", species = "SNORLAX",
})
allowed = catchHook(function() return true end, {
  game = game, battle = bonusStatic, species = "SNORLAX",
})
eq(allowed, true, "BONUS static can be caught")
h:emit("pokemon.caught", {
  game = game, battle = bonusStatic, species = "SNORLAX",
})
eq(h.save.encounter_areas["LANDMARK:25"].species, "SENTRET",
  "BONUS static bypasses and preserves an already-consumed area")
h.save.encounter_areas["LANDMARK:25"] = nil

h:setMap("ROUTE_37")
h.save.static_encounters = "forbid"
armStatic()
local forbiddenStatic = {
  wild = true, enemy = { species = "GYARADOS", shiny = true },
}
h:emit("battle.started", {
  battle = forbiddenStatic, kind = "wild", species = "GYARADOS",
})
allowed, denial = catchHook(function() return true end, {
  game = game, battle = forbiddenStatic, species = "GYARADOS",
})
eq(allowed, false, "FORBID blocks even a shiny static encounter")
eq(denial, "Static encounters\ncannot be caught!",
  "FORBID explains the static encounter policy")
h:emit("battle.ended", { battle = forbiddenStatic, result = "run" })
eq(h.save.encounter_areas["LANDMARK:24"], nil,
  "FORBID does not consume the surrounding area")

h:setMap("ROUTE_36")
armStatic()
scriptCommand(function() end, { generation = 2 }, "randomwildmon", {}, {
  op = "randomwildmon",
})
local scriptedWild = { wild = true, enemy = { species = "HOOTHOOT" } }
h:emit("battle.started", {
  battle = scriptedWild, kind = "wild", species = "HOOTHOOT",
})
eq(h.save.encounter_areas["LANDMARK:23"].status, "active",
  "randomwildmon scripts remain ordinary area encounters")
h:emit("battle.ended", { battle = scriptedWild, result = "run" })
h.save.encounter_areas["LANDMARK:23"] = nil
h.save.static_encounters = "area"

-- Dupes checks the complete evolution family and remembers catches even if
-- that Pokemon later leaves the party. SKIP preserves the route but forbids
-- catching the duplicate; LOSE burns it immediately.
h:setMap("ROUTE_31")
local skippedDupe = { wild = true, enemy = { species = "FURRET" } }
h:emit("battle.started", {
  battle = skippedDupe, kind = "wild", species = "FURRET",
})
eq(h.save.encounter_areas["LANDMARK:18"], nil,
  "SKIP family duplicate does not consume the route")
allowed, denial = catchHook(function() return true end, {
  game = game, battle = skippedDupe, species = "FURRET",
})
eq(allowed, false, "SKIP family duplicate cannot be caught")
eq(denial:lower():find("duplicate", 1, true) ~= nil, true,
  "SKIP duplicate denial explains why")
h:emit("battle.ended", { battle = skippedDupe, result = "run" })
eq(h.save.encounter_areas["LANDMARK:18"], nil,
  "leaving a skipped duplicate still preserves the route")

settings.opts.onChoose(settings.items[2], settings)
eq(h.save.dupes_mode, "lose", "duplicate policy can be changed to LOSE")
h:setMap("ROUTE_31")
local shinyDupe = {
  wild = true,
  enemy = { species = "FURRET", shiny = true },
}
h:emit("battle.started", {
  battle = shinyDupe, kind = "wild", species = "FURRET",
})
eq(h.save.encounter_areas["LANDMARK:18"], nil,
  "shiny duplicate bypasses LOSE without consuming the route")
allowed = catchHook(function() return true end, {
  game = game, battle = shinyDupe, species = "FURRET",
})
eq(allowed, true, "shiny duplicate can be caught under DUPES=LOSE")
h:emit("pokemon.caught", {
  game = game, battle = shinyDupe, species = "FURRET",
})
eq(h.save.encounter_areas["LANDMARK:18"], nil,
  "caught shiny duplicate still leaves the normal encounter available")
h:setMap("ROUTE_32")
local lostDupe = { wild = true, enemy = { species = "FURRET" } }
h:emit("battle.started", {
  battle = lostDupe, kind = "wild", species = "FURRET",
})
eq(h.save.encounter_areas["LANDMARK:19"].status, "failed",
  "LOSE family duplicate immediately burns the route")

settings.opts.onChoose(settings.items[2], settings)
eq(h.save.dupes_mode, "off", "duplicate clause can be disabled")
eq(settings.items[2].right, "OFF", "disabled duplicate clause shows as off")
h:setMap("ROUTE_31")
local allowedDupe = { wild = true, enemy = { species = "FURRET" } }
h:emit("battle.started", {
  battle = allowedDupe, kind = "wild", species = "FURRET",
})
eq(h.save.encounter_areas["LANDMARK:18"].status, "active",
  "OFF treats an evolution-family duplicate as the area's encounter")
allowed = catchHook(function() return true end, {
  game = game, battle = allowedDupe, species = "FURRET",
})
eq(allowed, true, "OFF allows an evolution-family duplicate to be caught")
h:emit("pokemon.caught", {
  game = game, battle = allowedDupe, species = "FURRET",
})
eq(h.save.encounter_areas["LANDMARK:18"].status, "caught",
  "catching a duplicate with the clause OFF consumes the area normally")
settings.opts.onChoose(settings.items[2], settings)
eq(h.save.dupes_mode, "skip", "duplicate policy cycles from OFF to SKIP")

-- Bonus acquisitions do not have an area record. Their evolution family must
-- remain duplicate-locked even after the Pokemon leaves every live storage.
h:emit("pokemon.received", { mon = { species = "ABRA" }, from = "link" })
h:setMap("ROUTE_39")
local receivedFamilyDupe = {
  wild = true, enemy = { species = "KADABRA" },
}
h:emit("battle.started", {
  battle = receivedFamilyDupe, kind = "wild", species = "KADABRA",
})
eq(h.save.encounter_areas["LANDMARK:26"], nil,
  "a released bonus Pokemon still skips its evolution family")
allowed, denial = catchHook(function() return true end, {
  game = game, battle = receivedFamilyDupe, species = "KADABRA",
})
eq(allowed, false, "permanent ownership blocks the released family")
eq(denial:lower():find("duplicate", 1, true) ~= nil, true,
  "permanent family denial identifies a duplicate")
h:emit("battle.ended", { battle = receivedFamilyDupe, result = "run" })

-- Branched, `into`-named lines must resolve too: owning TYROGUE makes a wild
-- HITMONTOP a SKIP duplicate, so running from it leaves the route open for the
-- next, genuinely new species rather than locking it as a burned encounter.
h:emit("pokemon.received", { mon = { species = "TYROGUE" }, from = "gift" })
h:setMap("ROUTE_40")
local branchedDupe = { wild = true, enemy = { species = "HITMONTOP" } }
h:emit("battle.started", {
  battle = branchedDupe, kind = "wild", species = "HITMONTOP",
})
eq(h.save.encounter_areas["LANDMARK:27"], nil,
  "a branched evolution duplicate does not consume the route")
allowed, denial = catchHook(function() return true end, {
  game = game, battle = branchedDupe, species = "HITMONTOP",
})
eq(allowed, false, "the branched-family duplicate cannot be caught")
h:emit("battle.ended", { battle = branchedDupe, result = "run" })
eq(h.save.encounter_areas["LANDMARK:27"], nil,
  "running from the branched duplicate leaves the route open")
local freshAfterDupe = { wild = true, enemy = { species = "RATTATA" } }
h:emit("battle.started", {
  battle = freshAfterDupe, kind = "wild", species = "RATTATA",
})
eq(h.save.encounter_areas["LANDMARK:27"].status, "active",
  "the next new species becomes the route's real encounter")
allowed = catchHook(function() return true end, {
  game = game, battle = freshAfterDupe, species = "RATTATA",
})
eq(allowed, true, "the new species can still be caught after a skipped dupe")
h:emit("pokemon.caught", {
  game = game, battle = freshAfterDupe, species = "RATTATA",
})
eq(h.save.encounter_areas["LANDMARK:27"].status, "caught",
  "catching the new species consumes the route normally")

-- Every way to leave an eligible encounter without catching it consumes the
-- area. Gold reports an enemy escape as "fled" and a whiteout as "lose".
for _, outcome in ipairs({ "run", "fled", "lose" }) do
  local landmark = ({ run = 20, fled = 21, lose = 22 })[outcome]
  h:setMap("ROUTE_" .. (landmark + 13))
  local battle = { wild = true, enemy = { species = "HOOTHOOT" } }
  h:emit("battle.started", {
    battle = battle, kind = "wild", species = "HOOTHOOT",
  })
  h:emit("battle.ended", { battle = battle, result = outcome })
  eq(h.save.encounter_areas["LANDMARK:" .. landmark].status, "failed",
    outcome .. " permanently burns the route")
end
h:setMap("ROUTE_33")
local ranScreen = {
  game = game,
  save = { inventory = { POKE_BALL = 2 } },
  battle = { wild = true, enemy = { species = "SENTRET" } },
  phase = "menu",
}
legacyBattleState.useItem(ranScreen, "POKE_BALL")
eq(ranScreen.message, "You ran from\nHOOTHOOT here!",
  "blocked ball identifies a prior run and its Pokemon")
eq(ranScreen.save.inventory.POKE_BALL, 2,
  "ran-from encounter refuses a ball without consuming it")

-- The toggle takes effect immediately. Trainer battles, the catch tutorial,
-- and the Bug-Catching Contest never create encounter records.
h.save.strict_encounters = false
h:setMap("ROUTE_36")
local disabledBattle = { wild = true, enemy = { species = "HOOTHOOT" } }
h:emit("battle.started", { battle = disabledBattle, kind = "wild" })
h:emit("battle.ended", { battle = disabledBattle, result = "run" })
eq(h.save.encounter_areas["LANDMARK:23"], nil,
  "disabled strict encounters do not track or consume areas")
delegated = false
allowed = catchHook(function()
  delegated = true
  return true
end, { game = game, battle = disabledBattle, species = "HOOTHOOT" })
eq(allowed, true, "disabled strict encounters allow ordinary catches")
eq(delegated, true, "disabled catches delegate to Gold")
h:setMap("ROUTE_29")
allowed = catchHook(function() return true end, {
  game = game, battle = { wild = true }, species = "SENTRET",
})
eq(allowed, true, "disabled setting temporarily permits a failed route")
h.save.strict_encounters = true
allowed = catchHook(function() return true end, {
  game = game, battle = { wild = true }, species = "SENTRET",
})
eq(allowed, false, "re-enabling restores the permanent route ban")

local exemptions = {
  { map = "ROUTE_37", battle = { wild = false,
      trainer = { class = "YOUNGSTER" } }, label = "trainer" },
  { map = "ROUTE_38", battle = { wild = true, tutorial = true,
      enemy = { species = "HOOTHOOT" } }, label = "tutorial" },
  { map = "ROUTE_39", battle = { wild = true, contest = true,
      enemy = { species = "HOOTHOOT" } }, label = "contest" },
}
for index, exemption in ipairs(exemptions) do
  h:setMap(exemption.map)
  h:emit("battle.started", { battle = exemption.battle,
    kind = exemption.battle.wild and "wild" or "trainer" })
  h:emit("battle.ended", { battle = exemption.battle, result = "run" })
  eq(h.save.encounter_areas["LANDMARK:" .. (23 + index)], nil,
    exemption.label .. " battle is exempt")
end

-- Gold v0.1.80 keeps tutorial/contest markers outside the Battle object. The
-- tutorial is identifiable by wBattleType, while an active contest lives in
-- save.bugContest.
h:setMap("ROUTE_38")
local legacyTutorial = { wild = true, battleType = 3,
  enemy = { species = "HOOTHOOT" } }
h:emit("battle.started", { battle = legacyTutorial, kind = "wild",
  battleType = 3, species = "HOOTHOOT" })
h:emit("battle.ended", { battle = legacyTutorial, result = "caught" })
eq(h.save.encounter_areas["LANDMARK:25"], nil,
  "Gold v0.1.80 tutorial battle is exempt")

h:setMap("ROUTE_39")
game.save.bugContest = { active = true }
local legacyContest = { wild = true, enemy = { species = "HOOTHOOT" } }
h:emit("battle.started", { battle = legacyContest, kind = "wild",
  species = "HOOTHOOT" })
h:emit("battle.ended", { battle = legacyContest, result = "run" })
eq(h.save.encounter_areas["LANDMARK:26"], nil,
  "Gold v0.1.80 Bug-Catching Contest battle is exempt")
game.save.bugContest.active = false

-- The ledger is ordinary mod.save data. A fresh installation against the same
-- save must enforce failures recorded before reload.
local reloadedMod, reloaded = newMod(h.save)
assert(loadfile(root .. "/main.lua"))()(reloadedMod)
local reloadedGame = {
  save = game.save,
  data = game.data,
  stack = {
    push = function() end,
  },
}
reloadedMod.game = reloadedGame
reloaded:setMap("ROUTE_29")
local reloadedCatch = reloaded.hooks["battle.catch_allowed"]
allowed = reloadedCatch(function() return true end, {
  game = reloadedGame, battle = { wild = true }, species = "SENTRET",
})
eq(allowed, false, "failed route remains blocked after save reload")
local reloadedSettings =
  reloaded.screens.Gen1RecompPlusNuzlockeSettings.new(reloadedGame)
eq(reloadedSettings.opts.footer, "LOCKED SEL:INFO",
  "rules remain locked after save reload")

-- A caught route proves an older mod version already saw the player use a
-- Ball. Upgrading must preserve that started run even if no Balls remain.
local upgradedMod, upgraded = newMod({
  strict_encounters = true,
  encounter_areas = {
    ["LANDMARK:16"] = { status = "caught", species = "SENTRET" },
  },
})
assert(loadfile(root .. "/main.lua"))()(upgradedMod)
local upgradedGame = {
  save = { party = {}, boxes = {}, inventory = {} },
  data = game.data,
}
upgradedMod.game = upgradedGame
upgraded:setMap("ROUTE_30")
local upgradedBattle = { wild = true, enemy = { species = "HOOTHOOT" } }
upgraded:emit("battle.started", {
  battle = upgradedBattle, kind = "wild", species = "HOOTHOOT",
})
eq(upgraded.save.nuzlocke_started, true,
  "existing caught route migrates to a permanently started run")
eq(upgraded.save.encounter_areas["LANDMARK:17"].status, "active",
  "upgraded run stays active even when no Balls remain")

-- AREA gifts can exist before the player owns a Ball. They must not trigger
-- the legacy caught-route migration and start wild encounter enforcement.
local giftOnlyMod, giftOnly = newMod({
  strict_encounters = true,
  gift_encounters = "area",
  encounter_areas = {
    ["LANDMARK:1"] = {
      status = "caught", species = "CYNDAQUIL", result = "gift",
    },
  },
})
assert(loadfile(root .. "/main.lua"))(giftOnlyMod)
local giftOnlyGame = {
  save = { party = {}, boxes = {}, inventory = {} },
  data = game.data,
}
giftOnlyMod.game = giftOnlyGame
giftOnly:setMap("ROUTE_29")
giftOnly:emit("battle.started", {
  battle = { wild = true, enemy = { species = "SENTRET" } },
  kind = "wild", species = "SENTRET",
})
eq(giftOnly.save.nuzlocke_started, nil,
  "a pre-Ball AREA gift does not start wild encounter enforcement")
eq(giftOnly.save.encounter_areas["LANDMARK:16"], nil,
  "a pre-Ball wild encounter remains free after receiving an AREA gift")

print(("strict encounters: %d checks passed"):format(checks))
