local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local saved = {}
local currentCap = 25
local hooks = {}
local variance = { -2, 0, 2 }
local varianceIndex = 0
local varianceEnabled = false
love = { math = { random = function(low, high)
  if not varianceEnabled then return 0 end
  varianceIndex = varianceIndex + 1
  local value = variance[varianceIndex] or 0
  assert(value >= low and value <= high)
  return value
end } }
local mod = {
  exports = { levelCaps = { current = function() return currentCap end } },
  save = { get = function(_, key, default)
    if saved[key] == nil then return default end
    return saved[key]
  end },
  hooks = { wrap = function(_, name, callback) hooks[name] = callback end },
}

local Battle = { new = function(opts) return opts end }
package.loaded[table.concat(
  { "src", "battle", "gen2", "Batt" .. "le" }, ".")] = Battle

local Mon = {}
function Mon.new(_, species, level, opts)
  local moves = opts and opts.moves
  if moves == nil then
    moves = { "MOVE" .. (level - 3), "MOVE" .. (level - 2),
      "MOVE" .. (level - 1), "MOVE" .. level }
  end
  return {
    species = species,
    level = level,
    moves = moves,
    dvs = opts and opts.dvs,
    hp = opts and opts.hp or level,
  }
end
package.loaded[table.concat(
  { "src", "battle", "gen2", "M" .. "on" }, ".")] = Mon

local World = {}
function World:repelSuppresses(level)
  self.checkedLevel = level
  return level < self.leadLevel
end
package.loaded[table.concat(
  { "src", "world", "gen2", "Wor" .. "ld" }, ".")] = World

mod.game = {
  data = { gen2Trainers = { classes = {
    YOUNGSTER = { trainers = { {
      id = "YOUNGSTER1", index = 1,
      party = {
        { species = "RATTATA", level = 5 },
        { species = "SPEAROW", level = 18 },
      },
    } } },
    BROCK = { trainers = { {
      id = "BROCK1", index = 1,
      party = {
        { species = "GRAVELER", level = 41,
          moves = { "DEFENSE_CURL", "ROCK_SLIDE" } },
        { species = "RHYHORN", level = 41 },
        { species = "ONIX", level = 42 },
      },
    } } },
  } } },
  save = { party = {
    { species = "CYNDAQUIL", level = 10 },
    { species = "TOGEPI", level = 50, isEgg = true },
    { species = "PIDGEY", level = 20 },
  } },
}

local feature = assert(loadfile(root .. "/features/level_scaling.lua"))()
feature.install(mod)
eq(type(hooks["trainer.party"]), "function",
  "trainer scaling composes through the public roster hook")

local function trainerBattle(opts)
  local trainer = opts.trainer
  trainer.party = hooks["trainer.party"](
    function(_, _, party) return party end,
    trainer.classId, trainer.memberId or 1, trainer.party)
  return Battle.new(opts)
end

local battle = Battle.new({
  data = mod.game.data,
  party = mod.game.save.party,
  wild = { species = "RATTATA", level = 5, moves = {}, dvs = {} },
})
eq(battle.wild.level, 16,
  "wild levels use 80 percent of the highest non-Egg party member")
eq(table.concat(battle.wild.moves, ","), "MOVE13,MOVE14,MOVE15,MOVE16",
  "scaled wild Pokemon learn their latest four natural moves")

mod.game.save.party = {
  { species = "CYNDAQUIL", level = 22 },
  { species = "PIDGEY", level = 29 },
}
currentCap = 30
local world = setmetatable({ leadLevel = 22 }, { __index = World })
local suppressed = world:repelSuppresses(3)
eq(suppressed, false,
  "Repel allows an encounter whose scaled level reaches the lead level")
eq(world.checkedLevel, 23, "Repel checks the encounter's scaled level")
battle = Battle.new({
  data = mod.game.data,
  party = mod.game.save.party,
  wild = { species = "RATTATA", level = 3, moves = { "TACKLE" }, dvs = {} },
})
eq(battle.wild.level, 23,
  "the battle reuses the exact level that passed the Repel check")
mod.game.save.party = {
  { species = "CYNDAQUIL", level = 10 },
  { species = "TOGEPI", level = 50, isEgg = true },
  { species = "PIDGEY", level = 20 },
}
currentCap = 25

mod.game.save.party[3].level = 25
currentCap = 30
varianceEnabled = true
local varied = {}
for index = 1, 3 do
  local encounter = Battle.new({
    data = mod.game.data,
    party = mod.game.save.party,
    wild = { species = "RATTATA", level = 5, moves = {}, dvs = {} },
  })
  varied[index] = encounter.wild.level
end
eq(table.concat(varied, ","), "18,20,22",
  "repeated scaling varies by two levels around the 80 percent target")
varianceEnabled = false
mod.game.save.party[3].level = 20
currentCap = 25

battle = Battle.new({
  data = mod.game.data,
  party = mod.game.save.party,
  roaming = 1,
  wild = { species = "RAIKOU", level = 5, hp = 3, moves = {}, dvs = {} },
})
eq(battle.wild.hp, 3,
  "scaling a previously damaged roamer preserves its remaining HP")

battle = Battle.new({
  data = mod.game.data,
  party = mod.game.save.party,
  wild = { species = "RATICATE", level = 18, moves = {}, dvs = {} },
})
eq(battle.wild.level, 18, "scaling never lowers a stronger wild encounter")

battle = Battle.new({
  data = mod.game.data,
  party = mod.game.save.party,
  wild = { species = "ENTEI", level = 30, moves = {}, dvs = {} },
})
eq(battle.wild.level, 30,
  "an above-cap vanilla encounter is preserved rather than lowered")

mod.game.save.party[3].level = 40
battle = Battle.new({
  data = mod.game.data,
  party = mod.game.save.party,
  wild = { species = "RATTATA", level = 5, moves = {}, dvs = {} },
})
eq(battle.wild.level, 25, "wild scaling never exceeds the active level cap")

saved.level_caps = false
battle = Battle.new({
  data = mod.game.data,
  party = mod.game.save.party,
  wild = { species = "RATTATA", level = 5, moves = {}, dvs = {} },
})
eq(battle.wild.level, 32,
  "disabling caps lets scaling use the full highest-party floor")
saved.level_caps = true

saved.level_scaling = false
battle = Battle.new({
  data = mod.game.data,
  party = mod.game.save.party,
  wild = { species = "RATTATA", level = 5, moves = {}, dvs = {} },
})
eq(battle.wild.level, 5, "disabling scaling restores vanilla wild levels")
saved.level_scaling = true

mod.game.save.party[3].level = 20
battle = trainerBattle({
  data = mod.game.data,
  party = mod.game.save.party,
  trainer = { classId = "YOUNGSTER", party = {
    { species = "RATTATA", level = 5, moves = {}, dvs = {} },
    { species = "SPEAROW", level = 18, moves = {}, dvs = {} },
  } },
})
eq(battle.trainer.party[1].level, 16,
  "ordinary trainer Pokemon scale to 80 percent of the party maximum")
eq(battle.trainer.party[2].level, 18,
  "ordinary trainer scaling never lowers a stronger roster member")
eq(table.concat(battle.trainer.party[1].moves, ","),
  "MOVE13,MOVE14,MOVE15,MOVE16",
  "scaled ordinary trainers learn their latest four natural moves")

-- Wilds and trainers carry their own "percent below the party max".
saved.wild_scaling_percent = 10
saved.trainer_scaling_percent = 40
battle = Battle.new({
  data = mod.game.data,
  party = mod.game.save.party,
  wild = { species = "RATTATA", level = 5, moves = {}, dvs = {} },
})
eq(battle.wild.level, 18, "wilds scale to their own percent below the maximum")
battle = trainerBattle({
  data = mod.game.data,
  party = mod.game.save.party,
  trainer = { classId = "YOUNGSTER", party = {
    { species = "RATTATA", level = 5, moves = {}, dvs = {} },
  } },
})
eq(battle.trainer.party[1].level, 12,
  "trainers scale to their own percent, independently of wilds")
saved.wild_scaling_percent = 100
battle = Battle.new({
  data = mod.game.data,
  party = mod.game.save.party,
  wild = { species = "RATTATA", level = 5, moves = {}, dvs = {} },
})
eq(battle.wild.level, 10,
  "an out-of-range percent is clamped to the 50 percent floor")
saved.wild_scaling_percent = nil
saved.trainer_scaling_percent = nil

saved.level_scaling = false
local vanillaTrainer = hooks["trainer.party"](
  function(_, _, party) return party end, "YOUNGSTER", 1,
  { { species = "RATTATA", level = 5, moves = {}, dvs = {} } })
eq(vanillaTrainer[1].level, 5,
  "disabling scaling restores vanilla trainer levels")
saved.level_scaling = true

currentCap = 52
mod.game.save.player = { kantoBadges = {} }
battle = trainerBattle({
  data = mod.game.data,
  party = mod.game.save.party,
  trainer = { classId = "BROCK", party = {
    { species = "GRAVELER", level = 41,
      moves = { "DEFENSE_CURL", "ROCK_SLIDE" }, dvs = {} },
    { species = "RHYHORN", level = 41, moves = {}, dvs = {} },
    { species = "ONIX", level = 42, moves = {}, dvs = {} },
  } },
})
eq(battle.trainer.party[1].level, 51,
  "Kanto leader scaling preserves the roster's level spread")
eq(battle.trainer.party[3].level, 52,
  "the first Kanto leader's ace scales to level 52")
eq(table.concat(battle.trainer.party[1].moves, ","),
  "DEFENSE_CURL,ROCK_SLIDE",
  "explicit trainer movesets survive level scaling")

currentCap = 61
mod.game.save.player.kantoBadges = {
  BOULDER = true, CASCADE = true, THUNDER = true,
}
battle = trainerBattle({
  data = mod.game.data,
  party = mod.game.save.party,
  trainer = { classId = "ERIKA", party = {
    { species = "TANGELA", level = 42, moves = {}, dvs = {} },
    { species = "VICTREEBEL", level = 46, moves = {}, dvs = {} },
  } },
})
eq(battle.trainer.party[1].level, 57,
  "later Kanto leaders retain their vanilla spread after scaling")
eq(battle.trainer.party[2].level, 61,
  "three Kanto badges set the next leader ace to level 61")

currentCap = 75
battle = trainerBattle({
  data = mod.game.data,
  party = mod.game.save.party,
  trainer = { classId = "BLUE", party = {
    { species = "PIDGEOT", level = 56, moves = {}, dvs = {} },
    { species = "GYARADOS", level = 58, moves = {}, dvs = {} },
  } },
})
eq(battle.trainer.party[1].level, 73,
  "Blue's team spread is preserved when his ace is raised")
eq(battle.trainer.party[2].level, 75, "Blue's ace scales to level 75")

currentCap = 81
battle = trainerBattle({
  data = mod.game.data,
  party = mod.game.save.party,
  trainer = { classId = "RED", party = {
    { species = "PIKACHU", level = 81, moves = {}, dvs = {} },
  } },
})
eq(battle.trainer.party[1].level, 81,
  "Red remains at his level 81 challenge target")

print("level scaling: " .. checks .. " checks passed")
