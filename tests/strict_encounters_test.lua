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
}

local function newMod(savedValues)
  local hookChains = {}
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
      wrap = function(_, name, callback) hookChains[name] = callback end,
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
            close = function(self) self.closed = true end }
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
    setMap = function(_, mapId) currentMap = mapId end,
    emit = function(_, name, payload)
      for _, callback in ipairs(listeners[name] or {}) do callback(payload) end
    end,
  }
  return mod, harness
end

local mod, h = newMod()
assert(loadfile(root .. "/main.lua"))()(mod)

-- Oak configures a new run through Gold's public intro steps. Answers are
-- persisted in mod.save, and the active save exposes the same settings from
-- START -> NUZLOCKE.
local introHook = h.hooks["intro.oak_speech.build"]
eq(type(introHook), "function", "new-run settings hook is registered")
local intro = introHook(function(steps) return steps end, {
  { id = "oak_welcome", kind = "say" },
  { id = "demo_mon", kind = "demo" },
})
eq(intro[2].saveKey, "strict_encounters",
  "Oak asks whether strict encounters are enabled")
eq(intro[3].saveKey, "dupes_mode", "Oak asks for duplicate policy")
eq(intro[4].saveKey, "shiny_clause", "Oak asks whether shinies are exempt")
eq(intro[5].saveKey, "permadeath", "Oak asks whether permadeath is enabled")
eq(intro[6].saveKey, "mandatory_nicknames",
  "Oak asks whether nicknames are mandatory")
eq(intro[7].saveKey, "level_caps",
  "Oak asks whether level caps are enabled")
eq(intro[8].saveKey, "level_scaling",
  "Oak asks whether level scaling is enabled")
eq(intro[9].saveKey, "forced_set_mode",
  "Oak asks whether Set mode is enforced")
eq(intro[10].saveKey, "no_battle_items",
  "Oak asks whether non-ball battle items are forbidden")
h:emit("intro.oak_speech.answered", {
  saveKey = "strict_encounters", value = true,
})
h:emit("intro.oak_speech.answered", {
  saveKey = "dupes_mode", value = "skip",
})
h:emit("intro.oak_speech.answered", {
  saveKey = "shiny_clause", value = true,
})
h:emit("intro.oak_speech.answered", {
  saveKey = "permadeath", value = true,
})
h:emit("intro.oak_speech.answered", {
  saveKey = "mandatory_nicknames", value = true,
})
h:emit("intro.oak_speech.answered", {
  saveKey = "level_caps", value = true,
})
h:emit("intro.oak_speech.answered", {
  saveKey = "level_scaling", value = true,
})
h:emit("intro.oak_speech.answered", {
  saveKey = "forced_set_mode", value = true,
})
h:emit("intro.oak_speech.answered", {
  saveKey = "no_battle_items", value = false,
})
eq(h.save.strict_encounters, true, "new-run strict setting is persisted")
eq(h.save.dupes_mode, "skip", "new-run duplicate policy is persisted")
eq(h.save.shiny_clause, true, "new-run shiny clause is persisted")
eq(h.save.permadeath, true, "new-run permadeath setting is persisted")
eq(h.save.mandatory_nicknames, true,
  "new-run mandatory nickname setting is persisted")
eq(h.save.level_caps, true, "new-run level cap setting is persisted")
eq(h.save.level_scaling, true, "new-run level scaling setting is persisted")
eq(h.save.forced_set_mode, true, "new-run Set-mode setting is persisted")
eq(h.save.no_battle_items, false,
  "new-run battle-item setting is persisted")

local game = {}
local startHook = h.hooks["ui.start_menu.items"]
eq(type(startHook), "function", "active-save settings hook is registered")
local rows = startHook(function(_, items) return items end, game, {
  { label = "POKéMON", value = "pokemon" },
  { label = "SAVE", value = "save" },
})
eq(rows[2].label, "NUZLOCKE", "START menu exposes Nuzlocke settings")
rows[2].onSelect(game)
eq(h:pushed().id, "Gen1RecompPlusNuzlockeSettings",
  "START row opens the settings screen")
local settings = h.screens.Gen1RecompPlusNuzlockeSettings.new(game)
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
eq(settings.items[8].right, "ON", "forced Set mode defaults to enabled")
settings.opts.onChoose(settings.items[8], settings)
eq(h.save.forced_set_mode, false,
  "active save can disable forced Set mode in-game")
eq(settings.items[8].right, "OFF", "disabled forced Set mode shows as off")
settings.opts.onChoose(settings.items[8], settings)
eq(h.save.forced_set_mode, true,
  "active save can re-enable forced Set mode in-game")
eq(settings.items[9].right, "OFF", "no battle items defaults to disabled")
settings.opts.onChoose(settings.items[9], settings)
eq(h.save.no_battle_items, true,
  "active save can forbid non-ball battle items in-game")
eq(settings.items[9].right, "ON", "enabled battle-item rule shows as on")
settings.opts.onChoose(settings.items[9], settings)
eq(h.save.no_battle_items, false,
  "active save can restore non-ball battle items in-game")

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
  },
  pokemon = {
    SENTRET = { evolutions = { { species = "FURRET" } } },
    FURRET = { evolutions = {} },
    HOOTHOOT = { evolutions = { { species = "NOCTOWL" } } },
    NOCTOWL = { evolutions = {} },
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

local first = { wild = true, enemy = { species = "SENTRET" } }
h:emit("battle.started", { battle = first, kind = "wild", species = "SENTRET" })
eq(h.save.encounter_areas["LANDMARK:16"].status, "active",
  "first encounter reserves its canonical area")
h:emit("battle.ended", { battle = first, result = "win" })
eq(h.save.encounter_areas["LANDMARK:16"].status, "failed",
  "knocking out the encounter permanently fails the area")
h:setMap("ROUTE_29_GATE")
local catchHook = h.hooks["battle.catch_allowed"]
eq(type(catchHook), "function", "catch enforcement hook is registered")
local delegated = false
local allowed, denial = catchHook(function()
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
}
reloadedMod.game = reloadedGame
reloaded:setMap("ROUTE_29")
local reloadedCatch = reloaded.hooks["battle.catch_allowed"]
allowed = reloadedCatch(function() return true end, {
  game = reloadedGame, battle = { wild = true }, species = "SENTRET",
})
eq(allowed, false, "failed route remains blocked after save reload")

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

print(("strict encounters: %d checks passed"):format(checks))
