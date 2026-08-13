local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local initCalls = 0
local collectCalls = 0
local Breeding = {}
function Breeding.dayCare(save)
  save.dayCare = save.dayCare or {
    man = {}, lady = {}, compatible = false, hasEgg = false,
  }
  return save.dayCare
end
function Breeding.initBreeding(_, save)
  initCalls = initCalls + 1
  local dayCare = Breeding.dayCare(save)
  dayCare.compatible = true
  dayCare.egg = { species = "PICHU", isEgg = true }
  return true
end
function Breeding.collectEgg(data, save)
  collectCalls = collectCalls + 1
  local dayCare = Breeding.dayCare(save)
  if not dayCare.hasEgg or not dayCare.egg then return false, "no_mon" end
  save.party = save.party or {}
  if #save.party >= 6 then return false, "party_full" end
  local egg = dayCare.egg
  save.party[#save.party + 1] = egg
  dayCare.egg = nil
  dayCare.hasEgg = false
  Breeding.initBreeding(data, save)
  return true, egg
end
package.loaded[table.concat({ "src", "core", "gen2", "Breeding" }, ".")] = Breeding

local baseOutsideCalls = 0
local DayCareMenu = {
  startOutside = function(menu)
    baseOutsideCalls = baseOutsideCalls + 1
    menu.baseOutside = true
  end,
}
package.loaded[table.concat(
  { "src", "ui", "gen2", "DayCareMenu" }, ".")] = DayCareMenu

local saved = { encounter_areas = {} }
local currentMap = "DAY_CARE"
local game = {
  save = { party = {}, dayCare = { man = {}, lady = {} } },
  data = { gen2Maps = { DAY_CARE = { landmark = 15 } } },
}
local mod = {
  game = game,
  save = {
    get = function(_, key, default)
      if saved[key] == nil then return default end
      return saved[key]
    end,
    set = function(_, key, value) saved[key] = value end,
  },
  world = { current = function() return { mapId = currentMap } end },
}

local feature = assert(loadfile(root .. "/features/breeding_eggs.lua"))()
feature.install(mod)

local function menu()
  return {
    game = game,
    say = function(self, pages, onDone)
      self.pages = pages
      self.onDone = onDone
    end,
    close = function(self) self.closed = true end,
  }
end

-- FORBID is the hard default and stops both clutch creation and collection.
game.save.dayCare.compatible = true
eq(Breeding.initBreeding(game.data, game.save), false,
  "FORBID prevents a breeding clutch")
eq(initCalls, 0, "FORBID bypasses Gold's clutch creation")
eq(game.save.dayCare.compatible, false,
  "FORBID stops an already-compatible pair producing an Egg")
local pending = { species = "PICHU", isEgg = true }
game.save.dayCare.hasEgg = true
game.save.dayCare.egg = pending
local ok, reason = Breeding.collectEgg(game.data, game.save)
eq(ok, false, "FORBID refuses an existing bred Egg")
eq(reason, "nuzlocke_egg_policy", "blocked collection reports its policy")
eq(game.save.dayCare.egg, pending, "blocked bred Egg remains at Day Care")
eq(#game.save.party, 0, "blocked bred Egg is not added")
local screen = menu()
DayCareMenu.startOutside(screen)
eq(screen.pages[1][1], "Breeding EGGS are",
  "FORBID explains the rule in the Day-Care screen")
screen.onDone()
eq(screen.closed, true, "policy refusal closes the conversation cleanly")

-- AREA permits exactly one successful receipt at the Day-Care landmark.
saved.breeding_eggs = "area"
game.save.dayCare.hasEgg = false
game.save.dayCare.egg = nil
eq(Breeding.initBreeding(game.data, game.save), true,
  "AREA allows a clutch while its landmark is unused")
eq(initCalls, 1, "AREA reaches Gold's normal clutch creation")
game.save.dayCare.hasEgg = true
game.save.party = { {}, {}, {}, {}, {}, {} }
ok, reason = Breeding.collectEgg(game.data, game.save)
eq(ok, false, "full party still refuses an AREA Egg")
eq(reason, "party_full", "full-party refusal remains Gold's normal result")
eq(saved.encounter_areas["LANDMARK:15"], nil,
  "failed full-party collection does not consume the area")
eq(game.save.dayCare.hasEgg, true, "full-party Egg remains retryable")

game.save.party = {}
ok, pending = Breeding.collectEgg(game.data, game.save)
eq(ok, true, "AREA allows the first bred Egg")
eq(game.save.party[1], pending, "received Egg reaches the party")
eq(saved.encounter_areas["LANDMARK:15"].status, "caught",
  "bred Egg consumes the Day-Care landmark")
eq(saved.encounter_areas["LANDMARK:15"].species, "PICHU",
  "bred Egg record retains its species")
eq(saved.encounter_areas["LANDMARK:15"].result, "breeding",
  "ledger distinguishes breeding from scripted gifts")
eq(game.save.dayCare.compatible, false,
  "AREA stops the parents producing another collectible Egg")
eq(game.save.dayCare.egg, nil, "AREA clears the uncollectible next clutch")

eq(Breeding.initBreeding(game.data, game.save), false,
  "used AREA prevents another clutch")
game.save.dayCare.hasEgg = true
game.save.dayCare.egg = { species = "PICHU", isEgg = true }
screen = menu()
DayCareMenu.startOutside(screen)
eq(screen.pages[1][1], "This area's",
  "used AREA explains why another Egg is blocked")
ok = Breeding.collectEgg(game.data, game.save)
eq(ok, false, "used AREA refuses collection before moving the Egg")
eq(#game.save.party, 1, "used AREA does not add another Egg")

-- BONUS preserves vanilla repeat breeding and never touches the area ledger.
saved.breeding_eggs = "bonus"
saved.encounter_areas["LANDMARK:15"] = nil
game.save.dayCare.hasEgg = false
game.save.dayCare.egg = nil
eq(Breeding.initBreeding(game.data, game.save), true,
  "BONUS allows clutch creation")
game.save.dayCare.hasEgg = true
ok = Breeding.collectEgg(game.data, game.save)
eq(ok, true, "BONUS allows Egg collection")
eq(saved.encounter_areas["LANDMARK:15"], nil,
  "BONUS never consumes the Day-Care landmark")
game.save.dayCare.hasEgg = true
ok = Breeding.collectEgg(game.data, game.save)
eq(ok, true, "BONUS permits repeated bred Eggs")
eq(#game.save.party, 3, "BONUS adds each successfully collected Egg")
screen = menu()
DayCareMenu.startOutside(screen)
eq(screen.baseOutside, true, "BONUS preserves Gold's normal Day-Care screen")
eq(baseOutsideCalls, 1, "allowed policy delegates exactly once")

print("breeding Egg policy: " .. checks .. " checks passed")
