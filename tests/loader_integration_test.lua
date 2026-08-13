-- Run from the gen1recomp++ repository root. This deliberately uses the real
-- production Loader rather than putting the mod directory on package.path.
package.path = "./?.lua;./?/init.lua;" .. package.path

local modRoot = "../gen1recomp-plus-randomizer-nuzlocke"
local function read(path)
  local file = assert(io.open(modRoot .. "/" .. path, "rb"))
  local body = file:read("*a")
  file:close()
  return body
end

local files = {
  ["mods/strict/manifest.json"] = read("manifest.json"),
  ["mods/strict/main.lua"] = read("main.lua"),
  ["mods/strict/features/strict_encounters.lua"] =
    read("features/strict_encounters.lua"),
}

local Sdk = require("tests.modkit.sdk")
local run = Sdk.loadMod("mods/strict", {
  fs = Sdk.memfs(files), generation = 2,
})

assert(run.mod and run.mod.state == "loaded",
  "production loader must load the enabled mod: "
    .. tostring(run.errors[1] or run.mod and run.mod.reason))
local hooks = require("tests.modkit.record").hooks(run.loader)
assert(hooks:depth("battle.catch_allowed") == 1,
  "loaded mod must install strict capture enforcement")
assert(hooks:depth("ui.start_menu.items") == 1,
  "loaded mod must expose in-game settings")

local game = {
  data = {
    gen2Maps = { ROUTE_29 = { landmark = 16 } },
    pokemon = {
      SENTRET = { evolutions = {} },
      HOOTHOOT = { evolutions = {} },
    },
  },
  save = { party = {}, boxes = {} },
  world = { map = { id = "ROUTE_29" }, player = {} },
}
run.loader.game = game

local menu = run.loader.hooks:call("ui.start_menu.items",
  function(_, items) return items end, game,
  { { label = "POK\195\169GEAR" }, { label = "SAVE" } })
assert(#menu == 3 and menu[2].label == "NUZLOCKE",
  "loaded mod must add START -> NUZLOCKE before SAVE")

local first = { wild = true, enemy = { species = "SENTRET" } }
run.loader.events:emit("battle.started", {
  battle = first, kind = "wild", species = "SENTRET",
})
run.loader.events:emit("pokemon.caught", {
  battle = first, game = game, species = "SENTRET",
})

local areas = run.loader.modSave.gen1recomp_plus_randomizer_nuzlocke
  and run.loader.modSave.gen1recomp_plus_randomizer_nuzlocke.encounter_areas
assert(areas and areas["LANDMARK:16"]
    and areas["LANDMARK:16"].status == "caught",
  "first catch must consume the landmark encounter")

local second = { wild = true, enemy = { species = "HOOTHOOT" } }
run.loader.events:emit("battle.started", {
  battle = second, kind = "wild", species = "HOOTHOOT",
})
local allowed = run.loader.hooks:call("battle.catch_allowed", function() return true end,
  { game = game, battle = second, species = "HOOTHOOT" })
assert(allowed == false,
  "a second species on the same landmark must be rejected")

run.release()
print("production loader integration: 6 checks passed")
