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
  ["mods/strict/features/ownership_history.lua"] =
    read("features/ownership_history.lua"),
  ["mods/strict/features/strict_encounters.lua"] =
    read("features/strict_encounters.lua"),
  ["mods/strict/features/permadeath.lua"] = read("features/permadeath.lua"),
  ["mods/strict/features/run_report.lua"] = read("features/run_report.lua"),
  ["mods/strict/features/run_completion.lua"] =
    read("features/run_completion.lua"),
  ["mods/strict/features/mandatory_nicknames.lua"] =
    read("features/mandatory_nicknames.lua"),
  ["mods/strict/features/gift_encounters.lua"] =
    read("features/gift_encounters.lua"),
  ["mods/strict/features/breeding_eggs.lua"] =
    read("features/breeding_eggs.lua"),
  ["mods/strict/features/wild_randomizer.lua"] =
    read("features/wild_randomizer.lua"),
  ["mods/strict/features/gift_randomizer.lua"] =
    read("features/gift_randomizer.lua"),
  ["mods/strict/features/static_randomizer.lua"] =
    read("features/static_randomizer.lua"),
  ["mods/strict/features/trainer_randomizer.lua"] =
    read("features/trainer_randomizer.lua"),
  ["mods/strict/features/item_randomizer.lua"] =
    read("features/item_randomizer.lua"),
  ["mods/strict/features/starter_randomizer.lua"] =
    read("features/starter_randomizer.lua"),
  ["mods/strict/features/level_caps.lua"] = read("features/level_caps.lua"),
  ["mods/strict/features/level_scaling.lua"] = read("features/level_scaling.lua"),
  ["mods/strict/features/forced_set_mode.lua"] =
    read("features/forced_set_mode.lua"),
  ["mods/strict/features/no_battle_items.lua"] =
    read("features/no_battle_items.lua"),
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
assert(hooks:depth("pokemon.nickname") == 1,
  "loaded mod must require names for catches and scripted gifts")
assert(hooks:depth("exp.gain") == 1,
  "loaded mod must enforce battle EXP level caps")
assert(hooks:depth("trainer.party") == 3,
  "loaded mod must randomize and scale trainers and map the rival starter line")
assert(hooks:depth("ui.options.rows") == 1,
  "loaded mod must lock Gold's Battle Style option")
assert(hooks:depth("script.command") == 4,
  "loaded mod must randomize static encounters, starter scripts and items")
assert(hooks:depth("encounter.species") == 1,
  "loaded mod must randomize ordinary wild encounter slots")
assert(hooks:depth("encounter.fishing") == 1,
  "loaded mod must randomize Gold fishing slots")

local nicknameRequired, nicknameDefault = run.loader.hooks:call(
  "pokemon.nickname", function() return false, "CYNDAQUIL" end,
  { source = "gift" })
assert(nicknameRequired == true and nicknameDefault == "CYNDAQUIL",
  "production hook must force starter/gift naming and preserve its default")

local NamingScreen = require("src.ui.gen2.NamingScreen")
local chosenName
local naming = NamingScreen.new({}, {
  type = "nickname", monName = "CYNDAQUIL",
  onDone = function(name) chosenName = name end,
})
naming.text = "CYNDAQUIL"
naming:accept()
assert(chosenName == nil,
  "production naming screen must reject the species default")
naming.text = "EMBER"
naming:accept()
assert(chosenName == "EMBER",
  "production naming screen must accept a custom nickname")

local BattleState = require("src.ui.gen2.BattleState")
local forcedCatch
BattleState.askNickname({
  answerNickname = function(_, answer) forcedCatch = answer end,
}, { species = "SENTRET" })
assert(forcedCatch == true,
  "production Gold catch path must skip the optional nickname prompt")

local forcedEggName
require("src.world.gen2.World").askYesNo({
  lastText = "Give a nickname to\nTOGEPI?",
}, function(answer)
  forcedEggName = answer
end)
assert(forcedEggName == true,
  "production overworld must force the egg naming path")

local game = {
  data = {
    gen2Maps = { ROUTE_29 = { landmark = 16 } },
    items = {
      POKE_BALL = { pocket = "BALL" },
      FAST_BALL = { pocket = "BALL" },
      POTION = { pocket = "ITEM" },
    },
    pokemon = {
      SENTRET = { index = 161, evolutions = {}, growthRate = "MEDIUM_FAST",
        baseStats = { hp = 35, attack = 46, defense = 34, speed = 20,
          specialAttack = 35, specialDefense = 45 },
        types = {}, levelMoves = {} },
      HOOTHOOT = { index = 163, evolutions = {}, growthRate = "MEDIUM_FAST",
        baseStats = { hp = 60, attack = 30, defense = 30, speed = 50,
          specialAttack = 36, specialDefense = 56 },
        types = {}, levelMoves = {
          { level = 2, move = "MOVE_A" },
          { level = 4, move = "MOVE_B" },
          { level = 6, move = "MOVE_C" },
          { level = 8, move = "MOVE_D" },
          { level = 9, move = "MOVE_E" },
        } },
      CHIKORITA = { index = 152, evolutions = { { into = "BAYLEEF" } },
        growthRate = "MEDIUM_SLOW", baseStats = { hp = 45, attack = 49,
          defense = 65, speed = 45, specialAttack = 49, specialDefense = 65 },
        types = {}, levelMoves = {} },
      BAYLEEF = { index = 153, evolutions = { { into = "MEGANIUM" } },
        growthRate = "MEDIUM_SLOW", baseStats = {}, types = {}, levelMoves = {} },
      MEGANIUM = { index = 154, evolutions = {}, growthRate = "MEDIUM_SLOW",
        baseStats = {}, types = {}, levelMoves = {} },
      CYNDAQUIL = { index = 155, evolutions = { { into = "QUILAVA" } },
        growthRate = "MEDIUM_SLOW", baseStats = { hp = 39, attack = 52,
          defense = 43, speed = 65, specialAttack = 60, specialDefense = 50 },
        types = {}, levelMoves = {} },
      QUILAVA = { index = 156, evolutions = { { into = "TYPHLOSION" } },
        growthRate = "MEDIUM_SLOW", baseStats = {}, types = {}, levelMoves = {} },
      TYPHLOSION = { index = 157, evolutions = {}, growthRate = "MEDIUM_SLOW",
        baseStats = {}, types = {}, levelMoves = {} },
      TOTODILE = { index = 158, evolutions = { { into = "CROCONAW" } },
        growthRate = "MEDIUM_SLOW", baseStats = { hp = 50, attack = 65,
          defense = 64, speed = 43, specialAttack = 44, specialDefense = 48 },
        types = {}, levelMoves = {} },
      CROCONAW = { index = 159, evolutions = { { into = "FERALIGATR" } },
        growthRate = "MEDIUM_SLOW", baseStats = {}, types = {}, levelMoves = {} },
      FERALIGATR = { index = 160, evolutions = {}, growthRate = "MEDIUM_SLOW",
        baseStats = {}, types = {}, levelMoves = {} },
    },
    moves = {
      MOVE_A = { pp = 10 }, MOVE_B = { pp = 10 },
      MOVE_C = { pp = 10 }, MOVE_D = { pp = 10 },
      MOVE_E = { pp = 10 },
    },
  },
  save = { party = {}, boxes = {}, inventory = {} },
  options = { battleStyle = "SHIFT" },
  world = { map = { id = "ROUTE_29" }, player = {} },
}
run.loader.game = game
run.loader.events:emit("game.ready", { game = game })
assert(game.options.battleStyle == "SET",
  "production game-ready path must immediately force Set mode")
local optionRows = run.loader.hooks:call("ui.options.rows",
  function(_, rows) return rows end, game, {
    { id = "battleStyle", key = "battleStyle", values = { "SHIFT", "SET" } },
  })
assert(#optionRows[1].values == 1 and optionRows[1].values[1] == "SET",
  "production Gold option row must disable Shift mode")
local setScreen = { game = game, battle = {
  player = { hp = 10 }, trainer = {},
  party = { { hp = 10 }, { hp = 10 } },
} }
assert(BattleState.shiftOfferAllowed(setScreen) == false,
  "production post-KO flow must not offer a free switch")

local exports = run.loader.exports.gen1recomp_plus_randomizer_nuzlocke
local activeCap, capTarget = exports.levelCaps.current(game)
assert(activeCap == 9 and capTarget == "FALKNER",
  "production loader must expose the new-run cap for future scaling")
local ItemEffects = require("src.core.gen2.ItemEffects")
local cappedCandy = ItemEffects.useOnMon(
  "RARE_CANDY", { species = "SENTRET", level = 9 }, game.data)
assert(cappedCandy.used == false,
  "production Gold Rare Candy path must refuse at the active cap")

game.save.party = { { species = "CYNDAQUIL", level = 20, hp = 20 } }
local scaledParty = run.loader.hooks:call("trainer.party",
  function(_, _, party) return party end, "YOUNGSTER", 1,
  { { species = "HOOTHOOT", level = 3, moves = {},
      dvs = { attack = 8, defense = 8, speed = 8, special = 8 } } })
assert(scaledParty[1].level == 9,
  "production trainer hook must scale to the highest-party floor and cap")
assert(scaledParty[1].moves[1].id == "MOVE_B"
    and scaledParty[1].moves[4].id == "MOVE_E",
  "production trainer scaling must regenerate the latest four natural moves")
local Battle = require("src.battle.gen2.Battle")
local scaledWild = Battle.new({ data = game.data, party = game.save.party,
  wild = { species = "HOOTHOOT", level = 3, moves = {},
    dvs = { attack = 8, defense = 8, speed = 8, special = 8 } } })
assert(scaledWild.enemy.level == 9,
  "production Gold wild battle path must apply party-based scaling")
assert(scaledWild.enemy.moves[1].id == "MOVE_B"
    and scaledWild.enemy.moves[4].id == "MOVE_E",
  "production wild scaling must regenerate the latest four natural moves")

game.save.party = {
  { species = "CYNDAQUIL", level = 8, hp = 8 },
  { species = "SENTRET", level = 20, hp = 20 },
}
game.save.repelSteps = 5
local World = require("src.world.gen2.World")
assert(World.repelSuppresses({ game = game }, 3) == false,
  "production Repel path must use the scaled encounter level")
local repelWild = Battle.new({ data = game.data, party = game.save.party,
  wild = { species = "HOOTHOOT", level = 3, moves = {},
    dvs = { attack = 8, defense = 8, speed = 8, special = 8 } } })
assert(repelWild.enemy.level == 9,
  "the wild battle must reuse the exact level accepted by Repel")
game.save.repelSteps = nil
game.save.party = { { species = "CYNDAQUIL", level = 20, hp = 20 } }

local menu = run.loader.hooks:call("ui.start_menu.items",
  function(_, items) return items end, game,
  { { label = "POK\195\169GEAR" }, { label = "SAVE" } })
assert(#menu == 3 and menu[2].label == "RULESET",
  "loaded mod must add START -> RULESET before SAVE")

local free = { wild = true, enemy = { species = "SENTRET" } }
run.loader.events:emit("battle.started", {
  battle = free, kind = "wild", species = "SENTRET",
})
run.loader.events:emit("battle.ended", { battle = free, result = "run" })
local bucket = run.loader.modSave.gen1recomp_plus_randomizer_nuzlocke
assert(not (bucket and bucket.encounter_areas
    and bucket.encounter_areas["LANDMARK:16"]),
  "encounter before receiving any Ball must remain free")

bucket = bucket or {}
run.loader.modSave.gen1recomp_plus_randomizer_nuzlocke = bucket
bucket.trainer_randomizer = "chaos"
bucket.trainer_legendaries = "exclude"
bucket.trainer_bosses = "include"
bucket.randomizer_seed = 123
local randomizedTrainer = run.loader.hooks:call("trainer.party",
  function(_, _, party) return party end, "YOUNGSTER", "YOUNGSTER1",
  { { species = "HOOTHOOT", level = 3, moves = {},
      dvs = { attack = 9, defense = 8, speed = 8, special = 8 } } })
assert(randomizedTrainer[1].species ~= "HOOTHOOT"
    and randomizedTrainer[1].level == 9,
  "production trainer chain must randomize after applying level scaling")
bucket.trainer_randomizer = "off"

bucket.wild_randomizer = "chaos"
bucket.wild_legendaries = "exclude"
bucket.randomizer_seed = 123
local randomized = run.loader.hooks:call("encounter.species",
  function(encounter) return encounter end,
  { species = "SENTRET", level = 3, slot = 1 },
  { kind = "wild", mapId = "ROUTE_29", terrain = "grass",
    daytime = "day", data = game.data })
assert(randomized.species ~= "SENTRET" and randomized.level == 3,
  "production wild hook must replace species without changing its level")
bucket.wild_randomizer = "off"

bucket.static_randomizer = "chaos"
bucket.static_legendaries = "match"
local staticCommand
run.loader.hooks:call("script.command",
  function(_, _, _, cmd) staticCommand = cmd end,
  { generation = 2, mapId = "ROUTE_36", scriptKey = "44:5770",
    object = 7 },
  "loadwildmon", {},
  { op = "loadwildmon", species = 161, level = 20 })
assert(staticCommand.species ~= 161 and staticCommand.level == 20,
  "production static hook must replace species without changing its level")
run.loader.events:emit("script.ended", {})
bucket.static_randomizer = "off"

bucket.starter_randomizer = "chaos"
bucket.starter_legendaries = "exclude"
local starterChoices = exports.starterRandomizer.choices(game.data)
local starterCommand
run.loader.hooks:call("script.command",
  function(_, _, _, cmd) starterCommand = cmd end,
  { generation = 2, mapId = "ELMS_LAB", scriptKey = "60:starter",
    object = 2 },
  "givepoke", { 155, 5, 173, 0 },
  { op = "givepoke", species = 155, level = 5, item = 173,
    args = { 155, 5, 173, 0 } })
assert(starterCommand.species
    == game.data.pokemon[starterChoices.CYNDAQUIL].index
    and starterCommand.level == 5 and starterCommand.item == 173,
  "production starter hook must synchronize the scripted grant")
local starterPromptName, starterPrompt
run.loader.hooks:call("script.command",
  function(_, name, _, cmd)
    starterPromptName, starterPrompt = name, cmd
  end,
  { generation = 2, mapId = "ELMS_LAB", scriptKey = "60:40c6",
    object = 3 },
  "writetext", {}, { op = "writetext", text = "60:45e3" })
assert(starterPromptName == "rawtext"
    and starterPrompt.text:find(
      game.data.pokemon[starterChoices.CYNDAQUIL].name
        or starterChoices.CYNDAQUIL, 1, true),
  "production starter prompt must name the randomized choice")

local Vm = require("src.script.gen2.Vm")
local Events = require("src.world.gen2.Events")
local starterSeen = {}
local starterVm = Vm.new({
  ["60:starter"] = {
    { op = "pokepic", species = 155, object = 155, args = { 155 } },
    { op = "cry", id = 155 },
    { op = "getmonname", species = 155, buffer = 0 },
    { op = "givepoke", species = 155, level = 5, item = 173, trainer = 0 },
    { op = "end" },
  },
}, {}, Events.new(), {
  mapId = function() return "24:5" end,
  showPic = function(index) starterSeen.pic = index end,
  cry = function(index) starterSeen.cry = index end,
  getMonName = function(index) starterSeen.name = index return "TEST" end,
  givePoke = function(index, level, item)
    starterSeen.gift = { index = index, level = level, item = item }
  end,
})
assert(starterVm:start("60:starter"),
  "production VM must start the Elm starter script")
local expectedStarter = game.data.pokemon[starterChoices.CYNDAQUIL].index
assert(starterSeen.pic == expectedStarter
    and starterSeen.cry == expectedStarter
    and starterSeen.name == expectedStarter
    and starterSeen.gift and starterSeen.gift.index == expectedStarter,
  "production VM must dispatch the randomized starter through every command")
bucket.starter_randomizer = "off"

game.save.inventory.FAST_BALL = 1
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
bucket = run.loader.modSave.gen1recomp_plus_randomizer_nuzlocke
assert(bucket and bucket.nuzlocke_started == true,
  "receiving any Ball must permanently start the Nuzlocke")
game.save.inventory.FAST_BALL = nil

bucket.static_encounters = "bonus"
run.loader.hooks:call("script.command", function() end,
  { generation = 2 }, "loadwildmon", {}, {
    op = "loadwildmon", species = "HOOTHOOT", level = 5,
  })
local staticBonus = { wild = true, enemy = { species = "HOOTHOOT" } }
run.loader.events:emit("battle.started", {
  battle = staticBonus, kind = "wild", species = "HOOTHOOT",
})
local staticAllowed = run.loader.hooks:call("battle.catch_allowed",
  function() return true end,
  { game = game, battle = staticBonus, species = "SENTRET" })
assert(staticAllowed == true,
  "production static BONUS policy must allow the scripted catch")
run.loader.events:emit("pokemon.caught", {
  battle = staticBonus, game = game, species = "HOOTHOOT",
})
assert(not bucket.encounter_areas
    or not bucket.encounter_areas["LANDMARK:16"],
  "production static BONUS policy must preserve the surrounding area")
bucket.static_encounters = "area"

bucket.no_battle_items = true
game.save.inventory.POTION = 2
local itemScreen = { game = game, save = game.save, phase = "menu" }
BattleState.useItem(itemScreen, "POTION")
assert(game.save.inventory.POTION == 2,
  "production battle-item rule must refuse before consuming the item")
assert(itemScreen.message == "Only BALLS can be\nused in battle!"
    and itemScreen.phase == "resolving",
  "production battle-item refusal must explain the rule cleanly")
bucket.no_battle_items = false

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
assert(bucket.run_catches and #bucket.run_catches == 2,
  "production mod.save must persist the catch journal")
assert(bucket.run_catches[2].species == "SENTRET"
    and bucket.run_catches[2].location == "ROUTE 29",
  "catch journal must retain species and Gold location")

local PrizeMenu = require("src.ui.gen2.PrizeMenu")
local giftCounter = { kind = "mon" }
local giftPrize = { id = "SENTRET", cost = 0 }
bucket.gift_encounters = "area"
assert(PrizeMenu.check(game.save, giftCounter, giftPrize, game.data)
    == "gift_area",
  "production gift AREA policy must refuse on a consumed landmark")
bucket.gift_encounters = "bonus"
assert(PrizeMenu.check(game.save, giftCounter, giftPrize, game.data) == "ok",
  "production gift BONUS policy must bypass a consumed landmark")

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

local shiny = {
  wild = true,
  enemy = { species = "HOOTHOOT", shiny = true },
}
run.loader.events:emit("battle.started", {
  battle = shiny, kind = "wild", species = "HOOTHOOT",
})
shiny.enemy.shiny = false
allowed = run.loader.hooks:call("battle.catch_allowed",
  function() return true end,
  { game = game, battle = shiny, species = "HOOTHOOT" })
assert(allowed == true,
  "production loader must allow a shiny on an already-used landmark")
local shinyCaught = Catching.attempt({
  ball = "MASTER_BALL", species = "HOOTHOOT",
  maxHp = 20, hp = 20, catchRate = 255,
})
assert(shinyCaught == true,
  "Gold v0.1.80 catch-rate fallback must allow the shiny")
run.loader.events:emit("pokemon.caught", {
  battle = shiny, game = game, species = "HOOTHOOT",
})
assert(areas["LANDMARK:16"].species == "SENTRET"
    and areas["LANDMARK:16"].status == "caught",
  "shiny catch must not replace the landmark's normal encounter record")

local transformedNormal = {
  wild = true,
  enemy = { species = "DITTO", shiny = false },
}
run.loader.events:emit("battle.started", {
  battle = transformedNormal, kind = "wild", species = "DITTO",
})
transformedNormal.enemy.shiny = true
allowed = run.loader.hooks:call("battle.catch_allowed",
  function() return true end,
  { game = game, battle = transformedNormal, species = "DITTO" })
assert(allowed == false,
  "Transform cannot grant shiny-clause exemption to a normal encounter")
run.loader.events:emit("battle.ended", {
  battle = transformedNormal, result = "run",
})

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
assert(bucket.run_deaths and #bucket.run_deaths == 2,
  "production mod.save must persist the memorial")
assert(bucket.run_deaths[1].name == "SCOUT"
    and bucket.run_deaths[1].location == "ROUTE 29",
  "memorial must retain nickname and death location")

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

local completionScreen
game.data.screens = game.data.screens or {}
game.data.screens.Gen1RecompPlusNuzlockeComplete =
  assert(run.loader.content.screens:get("Gen1RecompPlusNuzlockeComplete"))
game.stack = {
  push = function(_, state) completionScreen = state end,
  top = function() return completionScreen end,
  pop = function() completionScreen = nil end,
}
local redBattle = {
  trainer = { classId = "RED" }, party = game.save.party, outcome = "win",
  clearAllVolatiles = function() end,
}
run.loader.events:emit("battle.ended", {
  battle = redBattle, result = "win",
})
assert(bucket.nuzlocke_completed == true,
  "production Red victory must permanently complete the run")
local redCallback = false
local redScreen = {
  game = game, save = game.save, battle = redBattle, phase = "party",
  stopAlarm = function() end,
  clearMenuCursors = function() end,
  givePokerus = function() end,
  onDone = function() redCallback = true end,
}
BattleState.finishBattle(redScreen)
assert(redCallback == true,
  "production completion must preserve Red's post-battle callback")
assert(completionScreen and completionScreen.title == "NUZLOCKE COMPLETE",
  "production completion must appear after battle cleanup")
assert(#game.save.party == 1 and game.save.party[1] == backup,
  "completion must preserve the surviving final party")

run.release()
print("production loader integration: 44 checks passed")
