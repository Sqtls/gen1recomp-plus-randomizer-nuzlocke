local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local listeners = {}
local World = {
  load = function() end,
  poisonFaintScript = function(world)
    world.originalPoisonCalled = true
  end,
  askYesNo = function() end,
}
local worldModule = table.concat({ "src", "world", "gen2", "World" }, ".")
package.loaded[worldModule] = World
local saved = {
  nuzlocke_started = true,
  permadeath = true,
}
local scout = { species = "SENTRET", nickname = "SCOUT", level = 8, hp = 0 }
local pressed = {}
local game = {
  save = {
    party = { scout }, boxes = {},
    player = {
      badges = { ZEPHYR = true, HIVE = true },
      kantoBadges = { BOULDER = true },
    },
    playTime = { hours = 12, minutes = 34 },
  },
  data = {
    pokemon = {
      SENTRET = { name = "SENTRET" },
      HOOTHOOT = { name = "HOOTHOOT" },
    },
    gen2Maps = { ROUTE_29 = { landmark = 2 } },
    landmarks = { [2] = { name = "ROUTE 29" } },
  },
  input = { wasPressed = function(_, key) return pressed[key] == true end },
}
local drawn = {}
local mod = {
  game = game,
  exports = {},
  events = {
    on = function(_, name, callback)
      listeners[name] = listeners[name] or {}
      listeners[name][#listeners[name] + 1] = callback
    end,
  },
  save = {
    get = function(_, key, default)
      if saved[key] == nil then return default end
      return saved[key]
    end,
    set = function(_, key, value) saved[key] = value end,
  },
  world = { current = function() return { mapId = "ROUTE_29" } end },
  ui = {
    Font = {
      width = function(text) return #text * 8 end,
      draw = function(text, x, y)
        drawn[#drawn + 1] = { text = text, x = x, y = y }
      end,
      drawCode = function(code, x, y)
        drawn[#drawn + 1] = { code = code, x = x, y = y }
      end,
    },
    Theme = { cursor = 0xed },
  },
}

love = {
  graphics = {
    setColor = function() end,
    rectangle = function() end,
  },
}

local feature = assert(loadfile(root .. "/features/run_report.lua"))()
feature.install(mod)

local function emit(name, payload)
  for _, callback in ipairs(listeners[name] or {}) do callback(payload) end
end

emit("pokemon.caught", { game = game, species = "HOOTHOOT" })
eq(#saved.run_catches, 1, "successful catch is journalled")
eq(saved.run_catches[1].species, "HOOTHOOT", "catch records species")
eq(saved.run_catches[1].location, "ROUTE 29", "catch records landmark")
emit("pokemon.caught", {
  game = game, battle = { roaming = 1 }, species = "RAIKOU",
})
eq(saved.run_catches[2].location, "ROAMING POKéMON",
  "roaming catch is recorded outside the route category")

local battle = { wild = true }
emit("battle.fainted", { battle = battle, battler = scout })
emit("battle.fainted", { battle = battle, battler = scout })
eq(#saved.run_deaths, 1, "player death is journalled exactly once")
eq(saved.run_deaths[1].name, "SCOUT", "death records nickname")
eq(saved.run_deaths[1].species, "SENTRET", "death records species")
eq(saved.run_deaths[1].level, 8, "death records level")
eq(saved.run_deaths[1].location, "ROUTE 29", "death records landmark")

local enemy = { species = "HOOTHOOT", level = 4, hp = 0 }
emit("battle.fainted", { battle = battle, battler = enemy })
eq(#saved.run_deaths, 1, "enemy faint is excluded from the memorial")

local poisonDeath = { species = "HOOTHOOT", nickname = "NIGHT", level = 6,
  hp = 0 }
game.save.party = { poisonDeath }
local world = { game = game }
World.poisonFaintScript(world, { fainted = { 1 }, whiteout = true })
eq(world.originalPoisonCalled, true,
  "run journal preserves Gold's poison-faint handling")
eq(#saved.run_deaths, 2, "overworld poison death is journalled")
eq(saved.run_deaths[2].name, "NIGHT", "poison death records nickname")
eq(saved.run_deaths[2].location, "ROUTE 29",
  "poison death records landmark")

saved.run_journal_version = nil
saved.run_history_incomplete = nil
emit("save.loaded", { save = game.save })
eq(saved.run_journal_version, 1, "existing save adopts journal version")
eq(saved.run_history_incomplete, true,
  "existing active run marks pre-upgrade history incomplete")

saved.run_journal_version = nil
saved.run_history_incomplete = nil
emit("save.created", { save = game.save })
eq(saved.run_journal_version, 1, "new run starts a versioned journal")
eq(saved.run_history_incomplete, nil,
  "new run does not claim missing history")

saved.run_catches = {
  { species = "SENTRET", name = "SENTRET", location = "ROUTE 29" },
  { species = "HOOTHOOT", name = "NIGHT", location = "ROUTE 30" },
}
saved.run_deaths = {
  { species = "SENTRET", name = "SCOUT", level = 8,
    location = "VIOLET CITY" },
}
saved.encounter_areas = {
  ["LANDMARK:2"] = { status = "caught", species = "SENTRET",
    mapId = "ROUTE_29" },
  ["LANDMARK:3"] = { status = "failed", species = "PIDGEY",
    mapId = "ROUTE_30", result = "run" },
  ["LANDMARK:4"] = { status = "failed", species = "HOOTHOOT",
    mapId = "ROUTE_31", result = "fled" },
  ["ROAMER:2"] = { status = "failed", species = "ENTEI",
    mapId = "ROUTE_37", result = "win", category = "roamer", roaming = 2 },
}

eq(type(mod.exports.runReport), "table", "run report exports its failed screen")
local deleted = 0
local returnedToTitle = false
game.returnToTitle = function() returnedToTitle = true end
local screen = mod.exports.runReport.newFailedScreen(game, function()
  deleted = deleted + 1
  return true
end)
eq(screen.page, 1, "failed report opens on summary")
drawn = {}
screen:draw()
local summary = {}
for _, call in ipairs(drawn) do
  if call.text then summary[call.text] = true end
end
eq(summary["BADGES  3"], true, "summary shows all Gold badges")
eq(summary["TIME  12:34"], true, "summary shows run play time")
eq(summary["CAUGHT  2"], true, "summary shows successful catches")
eq(summary["FAILED  3"], true, "summary shows failed encounters")
eq(summary["LOST  1"], true, "summary shows memorial count")

pressed = { right = true }
screen:update()
eq(screen.page, 2, "right opens encounter history")
drawn = {}
screen:draw()
local encounterText = {}
for _, call in ipairs(drawn) do
  if call.text then encounterText[call.text] = true end
end
eq(encounterText["CAUGHT SENTRET"], true,
  "encounter page lists caught Pokemon")
eq(encounterText["RAN: PIDGEY"], true,
  "encounter page lists failed Pokemon and reason")

pressed = { down = true }
screen:update()
eq(screen.scroll, 2, "down scrolls a longer encounter history")
screen:update()
eq(screen.scroll, 3, "encounter history reaches roaming records")
drawn = {}
screen:draw()
encounterText = {}
for _, call in ipairs(drawn) do
  if call.text then encounterText[call.text] = true end
end
eq(encounterText["KO: ENTEI"], true,
  "encounter page lists a defeated roaming slot")
eq(encounterText["ROAMING POKéMON"], true,
  "roaming failure is not attributed to its random route")
drawn = {}
screen:draw()
local scrolledText = {}
for _, call in ipairs(drawn) do
  if call.text then scrolledText[call.text] = true end
end
eq(scrolledText["FLED: HOOTHOOT"], true,
  "scrolled encounter history reveals later entries")

pressed = { right = true }
screen:update()
eq(screen.page, 3, "right opens memorial")
drawn = {}
screen:draw()
local memorialText = {}
for _, call in ipairs(drawn) do
  if call.text then memorialText[call.text] = true end
end
eq(memorialText["SCOUT  LV8"], true,
  "memorial lists nickname and death level")
eq(memorialText["VIOLET CITY"], true,
  "memorial lists death location")

saved.run_history_incomplete = true
saved.run_deaths = {}
local partial = mod.exports.runReport.newFailedScreen(game, function()
  return true
end)
pressed = { left = true }
partial:update()
drawn = {}
partial:draw()
local partialText = {}
for _, call in ipairs(drawn) do
  if call.text then partialText[call.text] = true end
end
eq(partialText["EARLIER LOSSES"], true,
  "upgraded run memorial warns about unrecorded earlier losses")
eq(partialText["NOT RECORDED"], true,
  "partial memorial does not present missing history as zero deaths")
saved.run_history_incomplete = nil
saved.run_deaths = {
  { species = "SENTRET", name = "SCOUT", level = 8,
    location = "VIOLET CITY" },
}

pressed = { b = true }
screen:update()
eq(returnedToTitle, false, "B cannot leave the failed report")
pressed = { a = true }
screen:update()
eq(deleted, 1, "restart confirms failed save deletion")
eq(returnedToTitle, true, "restart returns to title")

local survivor = {
  species = "HOOTHOOT", nickname = "NIGHT", level = 81, hp = 150,
}
game.save.party = { survivor }
local popped = 0
local completion
game.stack = {
  top = function() return completion end,
  pop = function() popped = popped + 1 end,
}
returnedToTitle = false
completion = mod.exports.runReport.newCompletedScreen(game)
eq(completion.title, "NUZLOCKE COMPLETE",
  "successful report uses the completion title")
eq(completion.pages[2].name, "FINAL PARTY",
  "successful report includes a final-party page")
eq(completion.pages[2].entries[1].top, "NIGHT  LV81",
  "final party lists nickname and finishing level")
eq(completion.pages[2].entries[1].bottom, "HOOTHOOT",
  "final party retains the underlying species")
drawn = {}
completion:draw()
local completedText = {}
for _, call in ipairs(drawn) do
  if call.text then completedText[call.text] = true end
end
eq(completedText["A: CONTINUE PLAYING"], true,
  "successful report offers continued play")
eq(completedText["B: RETURN TO TITLE"], true,
  "successful report offers a title return")

pressed = { a = true }
completion:update()
eq(popped, 1, "continue closes only the completion report")
eq(returnedToTitle, false, "continue preserves the active game")
pressed = { b = true }
completion:update()
eq(returnedToTitle, true, "title action leaves without deleting the save")

print(("run report: %d checks passed"):format(checks))
