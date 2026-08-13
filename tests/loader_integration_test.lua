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
  ["mods/strict/features/permadeath.lua"] = read("features/permadeath.lua"),
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
assert(hooks:depth("input.step") == 1,
  "loaded mod must watch for the first Ball acquisition")

local game = {
  data = {
    gen2Maps = { ROUTE_29 = { landmark = 16 } },
    items = {
      POKE_BALL = { pocket = "BALL" },
      FAST_BALL = { pocket = "BALL" },
    },
    pokemon = {
      SENTRET = { evolutions = {} },
      HOOTHOOT = { evolutions = {} },
    },
  },
  save = { party = {}, boxes = {}, inventory = {} },
  world = { map = { id = "ROUTE_29" }, player = {} },
}
run.loader.game = game

local menu = run.loader.hooks:call("ui.start_menu.items",
  function(_, items) return items end, game,
  { { label = "POK\195\169GEAR" }, { label = "SAVE" } })
assert(#menu == 3 and menu[2].label == "NUZLOCKE",
  "loaded mod must add START -> NUZLOCKE before SAVE")

local free = { wild = true, enemy = { species = "SENTRET" } }
run.loader.events:emit("battle.started", {
  battle = free, kind = "wild", species = "SENTRET",
})
run.loader.events:emit("battle.ended", { battle = free, result = "run" })
local bucket = run.loader.modSave.gen1recomp_plus_randomizer_nuzlocke
assert(not (bucket and bucket.encounter_areas
    and bucket.encounter_areas["LANDMARK:16"]),
  "encounter before receiving any Ball must remain free")

game.save.inventory.FAST_BALL = 1
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
bucket = run.loader.modSave.gen1recomp_plus_randomizer_nuzlocke
assert(bucket and bucket.nuzlocke_started == true,
  "receiving any Ball must permanently start the Nuzlocke")
game.save.inventory.FAST_BALL = nil

local first = { wild = true, enemy = { species = "SENTRET" } }
run.loader.events:emit("battle.started", {
  battle = first, kind = "wild", species = "SENTRET",
})
run.loader.events:emit("pokemon.caught", {
  battle = first, game = game, species = "SENTRET",
})

local areas = bucket and bucket.encounter_areas
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

-- Gold v0.1.80 resolves balls through catch.rate and has no pre-throw
-- battle.catch_allowed call site. Exercise that shipped path with a guaranteed
-- Master Ball: strict enforcement still has to turn the second catch into a
-- failed roll.
local catchingPath = table.concat({ "src", "battle", "gen2", "Catching.lua" }, "/")
local Catching = assert(loadfile(catchingPath))()
local caught = Catching.attempt({
  ball = "MASTER_BALL", species = "HOOTHOOT",
  maxHp = 20, hp = 20, catchRate = 255,
})
assert(caught == false,
  "Gold v0.1.80 must reject a second catch through catch.rate")

local battleStateKey = table.concat({ "src", "ui", "gen2", "BattleState" }, ".")
local BattleState = assert(package.loaded[battleStateKey])
local screen = {
  game = game,
  save = { inventory = { POKE_BALL = 2 } },
  battle = second,
  phase = "menu",
}
BattleState.useItem(screen, "POKE_BALL")
assert(screen.save.inventory.POKE_BALL == 2,
  "blocked ball must not be consumed")
assert(screen.message == "Already caught\nSENTRET here!",
  "blocked ball must explain the recorded encounter")
assert(screen.phase == "resolving",
  "blocked ball message must enter the normal battle message phase")

local deadOne = { species = "SENTRET", nickname = "SCOUT", level = 8, hp = 0 }
local deadTwo = { species = "HOOTHOOT", level = 7, hp = 0 }
local backup = { species = "RATTATA", level = 6, hp = 13 }
local reserve = { species = "SENTRET", level = 5, hp = 11 }
game.save.party = { deadOne, deadTwo }
game.save.boxes = { [1] = { backup, reserve } }
game.save.inventory.REVIVE = 2
local wipe = {
  wild = true, party = game.save.party, outcome = "lose",
  clearAllVolatiles = function() end,
}
run.loader.events:emit("battle.fainted", {
  battle = wipe, battler = deadOne, side = { index = 1, key = "player" },
})
run.loader.events:emit("battle.fainted", {
  battle = wipe, battler = deadTwo, side = { index = 1, key = "player" },
})

local deathScreen = {
  game = game, save = game.save, battle = wipe, phase = "party",
}
BattleState.applyPartyItem(deathScreen, "REVIVE", "revive", deadOne)
assert(deadOne.hp == 0, "permadeath must refuse an in-battle Revive")
assert(game.save.inventory.REVIVE == 2,
  "refused Revive must not be consumed")

local partyAtRespawn
deathScreen.stopAlarm = function() end
deathScreen.clearMenuCursors = function() end
deathScreen.givePokerus = function() end
deathScreen.onDone = function() partyAtRespawn = game.save.party[1] end
BattleState.finishBattle(deathScreen)
assert(#game.save.party == 1,
  "party wipe must withdraw exactly one boxed Pokemon")
assert(game.save.party[1] == backup,
  "first living boxed Pokemon must save the run")
assert(partyAtRespawn == backup,
  "boxed rescue must happen before Gold handles respawn")
assert(#game.save.boxes[1] == 1 and game.save.boxes[1][1] == reserve,
  "rescued Pokemon must leave its box without reordering the rest")

run.release()
print("production loader integration: 19 checks passed")
