local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local saved = {
  encounter_areas = {
    ["LANDMARK:1"] = { status = "caught", species = "CYNDAQUIL" },
    ["LANDMARK:2"] = { status = "failed", species = "RATTATA" },
  },
}
local listeners = {}
local mod = {
  exports = {},
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  events = {
    on = function(_, event, callback)
      listeners[event] = listeners[event] or {}
      listeners[event][#listeners[event] + 1] = callback
    end,
  },
}
local function emit(event, value)
  for _, callback in ipairs(listeners[event] or {}) do callback(value) end
end

local feature = assert(loadfile(root .. "/features/ownership_history.lua"))()
feature.install(mod)

local game = {
  save = {
    pokedex = {
      caught = { TOGEPI = true },
      owned = { MACHOP = true },
    },
    party = { { species = "EEVEE" }, { species = "PICHU", isEgg = true } },
    boxes = { { { species = "DRATINI" } } },
    dayCare = {
      man = { mon = { species = "DITTO" } },
      lady = { mon = { species = "PIKACHU" } },
    },
  },
}
mod.game = game
local owned = mod.exports.ownershipHistory.sync(game)
eq(owned.CYNDAQUIL, true, "successful legacy encounters migrate")
eq(owned.RATTATA, nil, "failed legacy encounters do not migrate")
eq(owned.TOGEPI, true, "Gold caught Pokédex entries migrate")
eq(owned.MACHOP, true, "trade-style owned Pokédex entries migrate")
eq(owned.EEVEE, true, "party members migrate")
eq(owned.PICHU, true, "collected Eggs migrate by their species")
eq(owned.DRATINI, true, "boxed members migrate")
eq(owned.DITTO, true, "Day-Care man member migrates")
eq(owned.PIKACHU, true, "Day-Care lady member migrates")

emit("pokemon.caught", { species = "SENTRET" })
emit("pokemon.received", { mon = { species = "ABRA" } })
emit("egg.hatched", { species = "CLEFFA" })
emit("pokemon.evolved", {
  fromSpecies = "GOLBAT", toSpecies = "CROBAT",
})
eq(saved.ever_owned.SENTRET, true, "wild catches record immediately")
eq(saved.ever_owned.ABRA, true, "link receipts record immediately")
eq(saved.ever_owned.CLEFFA, true, "hatches record immediately")
eq(saved.ever_owned.GOLBAT, true, "evolution source records immediately")
eq(saved.ever_owned.CROBAT, true, "evolution result records immediately")

game.save.party = {}
game.save.boxes = {}
game.save.dayCare = {}
game.save.pokedex = { caught = {}, owned = {} }
saved.encounter_areas = {}
local family = { SENTRET = true, FURRET = true }
eq(mod.exports.ownershipHistory.ownsFamily(game, family), true,
  "death or release cannot erase family ownership")
eq(mod.exports.ownershipHistory.ownsFamily(game, { HOOTHOOT = true }), false,
  "an unseen family remains eligible")

print(("ownership history: %d checks passed"):format(checks))
