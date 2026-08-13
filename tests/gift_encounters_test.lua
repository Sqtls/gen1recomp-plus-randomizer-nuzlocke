local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local saved = { gift_encounters = "area", encounter_areas = {} }
local currentMap = "ELMS_LAB"
local failGift = false
local game = {
  data = { gen2Maps = {
    ELMS_LAB = { landmark = 1 },
    VIOLET_POKECENTER_1F = { landmark = 5 },
    GOLDENROD_GAME_CORNER = { landmark = 11 },
  } },
  save = { party = {} },
}

local World = {
  load = function(world)
    world.vm = {
      givePokeFn = function()
        if failGift then return nil end
        local mon = { species = "CYNDAQUIL" }
        game.save.party[#game.save.party + 1] = mon
        return { mon = mon }
      end,
      giveEggFn = function()
        local mon = { species = "TOGEPI", isEgg = true }
        game.save.party[#game.save.party + 1] = mon
        return true
      end,
    }
    return "loaded"
  end,
}
package.loaded[table.concat({ "src", "world", "gen2", "World" }, ".")] = World

local PrizeMenu
PrizeMenu = {
  check = function() return "ok" end,
  buy = function(save, counter, prize, data)
    local reason = PrizeMenu.check(save, counter, prize, data)
    if reason ~= "ok" then return reason end
    if counter.kind == "mon" then
      save.party[#save.party + 1] = { species = prize.id }
    end
    return "ok"
  end,
  refuse = function(self, reason) self.baseRefusal = reason end,
}
package.loaded[table.concat(
  { "src", "ui", "gen2", "PrizeMenu" }, ".")] = PrizeMenu

local listeners = {}
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
  events = { on = function(_, name, callback) listeners[name] = callback end },
}

local feature = assert(loadfile(root .. "/features/gift_encounters.lua"))()
feature.install(mod)

local world = { game = game }
eq(World.load(world), "loaded", "gift policy preserves Gold world loading")

-- The starter is claimable and counts at New Bark even though the wild
-- Nuzlocke has not started yet: gifts never require a Ball.
local result = world.vm.givePokeFn(155, 5, 0)
eq(type(result), "table", "AREA allows a starter on an unused landmark")
eq(#game.save.party, 1, "allowed starter reaches the party")
eq(saved.encounter_areas["LANDMARK:1"].status, "caught",
  "starter consumes its receipt landmark")
eq(saved.encounter_areas["LANDMARK:1"].species, "CYNDAQUIL",
  "gift record retains the obtained species")

local blockedResult
local blocked = coroutine.create(function()
  blockedResult = world.vm.givePokeFn(133, 20, 0)
end)
local resumed, refusal = coroutine.resume(blocked)
eq(resumed, true, "blocked scripted gift yields a refusal safely")
eq(refusal.kind, "text", "blocked scripted gift uses Gold's text flow")
eq(refusal.text, "This area's encounter\nis already used!",
  "blocked scripted gift explains the area rule")
eq(#game.save.party, 1, "blocked scripted gift is not added")
coroutine.resume(blocked)
eq(blockedResult, nil, "blocked scripted gift reports no acquisition")
eq(world.vm.aborted, true,
  "blocked scripted gift aborts before its claimed flag can be set")

-- Failed grants do not reserve an encounter.
saved.encounter_areas["LANDMARK:1"] = nil
failGift = true
World.load(world)
result = world.vm.givePokeFn(133, 20, 0)
eq(result, nil, "failed underlying gift remains failed")
eq(saved.encounter_areas["LANDMARK:1"], nil,
  "failed underlying gift does not consume the area")
failGift = false

-- Reload restores the real wrapped acquisition functions for the egg cases.
World.load(world)
currentMap = "VIOLET_POKECENTER_1F"
result = world.vm.giveEggFn(175, 5)
eq(result, true, "AREA allows Togepi's Egg on an unused landmark")
eq(saved.encounter_areas["LANDMARK:5"].species, "TOGEPI",
  "Egg consumes the landmark where it is received")

local partyBefore = #game.save.party
local blockedEggResult
blocked = coroutine.create(function()
  blockedEggResult = world.vm.giveEggFn(175, 5)
end)
resumed, refusal = coroutine.resume(blocked)
eq(resumed, true, "blocked Egg yields a refusal safely")
eq(refusal.text, "This area's encounter\nis already used!",
  "blocked Egg explains the area rule")
coroutine.resume(blocked)
result = blockedEggResult
eq(result, false, "AREA refuses another Egg on the consumed landmark")
eq(#game.save.party, partyBefore, "blocked Egg is not added")
eq(world.vm.aborted, true,
  "blocked Egg aborts before its received flag can be set")

saved.gift_encounters = "bonus"
World.load(world)
result = world.vm.giveEggFn(175, 5)
eq(result, true, "BONUS allows an Egg on a consumed landmark")
eq(saved.encounter_areas["LANDMARK:5"].species, "TOGEPI",
  "BONUS preserves the existing area record")

-- Game Corner Pokémon use the same pre-transaction rule.
currentMap = "GOLDENROD_GAME_CORNER"
saved.gift_encounters = "area"
saved.encounter_areas["LANDMARK:11"] = {
  status = "caught", species = "ABRA", mapId = currentMap,
}
local counter = { kind = "mon" }
local prize = { id = "DRATINI" }
eq(PrizeMenu.check(game.save, counter, prize, game.data), "gift_area",
  "AREA blocks a Game Corner Pokémon before confirmation")
local countBefore = #game.save.party
eq(PrizeMenu.buy(game.save, counter, prize, game.data), "gift_area",
  "AREA blocks the Game Corner transaction itself")
eq(#game.save.party, countBefore,
  "blocked Game Corner Pokémon is not added")
local menu = { close = function(self) self.closed = true end,
  say = function(self, pages, onDone)
    self.pages = pages
    if onDone then onDone() end
  end }
PrizeMenu.refuse(menu, "gift_area")
eq(menu.pages[1], "This area's encounter\nis already used!",
  "Game Corner refusal explains the area rule")

saved.encounter_areas["LANDMARK:11"] = nil
countBefore = #game.save.party
eq(PrizeMenu.buy(game.save, counter, prize, game.data), "ok",
  "AREA allows the first Game Corner Pokémon")
eq(#game.save.party, countBefore + 1,
  "allowed Game Corner Pokémon reaches the party")
eq(saved.encounter_areas["LANDMARK:11"].species, "DRATINI",
  "Game Corner Pokémon consumes its receipt landmark")

saved.gift_encounters = "bonus"
eq(PrizeMenu.check(game.save, counter, prize, game.data), "ok",
  "BONUS bypasses a consumed Game Corner landmark")
local bonusPrize = { id = "ABRA" }
countBefore = #game.save.party
eq(PrizeMenu.buy(game.save, counter, bonusPrize, game.data), "ok",
  "BONUS allows another Game Corner Pokémon")
eq(#game.save.party, countBefore + 1,
  "BONUS Game Corner Pokémon reaches the party")
eq(saved.encounter_areas["LANDMARK:11"].species, "DRATINI",
  "BONUS Game Corner purchase preserves the original area record")

eq(listeners["pokemon.received"], nil,
  "in-game and link trades are outside the gift policy")

print("gift encounters: " .. checks .. " checks passed")
