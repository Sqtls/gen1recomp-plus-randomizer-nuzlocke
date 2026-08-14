local LevelScaling = {}

local Battle = require("src.battle.gen2.Battle")
local Mon = require("src.battle.gen2.Mon")
local World = require("src.world.gen2.World")

local KANTO_LEADERS = {
  BLAINE = true, BROCK = true, ERIKA = true, JANINE = true,
  LT_SURGE = true, MISTY = true, SABRINA = true,
}

local function highestPartyLevel(party)
  local highest = 0
  for _, mon in ipairs(party or {}) do
    if not mon.isEgg then highest = math.max(highest, mon.level or 0) end
  end
  return highest
end

-- `percent` is how far BELOW the party's best level the scaler aims, so 20
-- means "80% of the party max".  Scaling only ever raises a level: the vanilla
-- level is the floor, so an encounter the cart already sets above the target
-- (a level 10 wild against a level 9 party) is left exactly as Gold shipped it.
local function scaledLevel(vanilla, party, cap, percent)
  local random = love and love.math and love.math.random or math.random
  local share = (100 - (percent or 20)) / 100
  local target = math.floor(highestPartyLevel(party) * share)
    + random(-2, 2)
  return math.min(math.max(vanilla or 1, target), cap or 100)
end

local function rebuild(mon, data, level, preserveHp, preserveMoves)
  if not (mon and level > (mon.level or 0)) then return mon end
  return Mon.new(data, mon.species, level, {
    moves = preserveMoves and mon.moves or nil,
    item = mon.item,
    dvs = mon.dvs,
    hp = preserveHp and mon.hp or nil,
  }) or mon
end

local function trainerRows(data, classId, member)
  local classes = data and data.gen2Trainers and data.gen2Trainers.classes
  local class = classes and classes[classId]
  if not class then return {} end
  for _, trainer in ipairs(class.trainers or {}) do
    if trainer.id == member or trainer.index == member then
      return trainer.party or {}
    end
  end
  return {}
end

local function bossTarget(classId, cap)
  if KANTO_LEADERS[classId] or classId == "BLUE" or classId == "RED" then
    return cap
  end
end

local function scaledTrainerParty(trainer, playerParty, data, challengeCap,
    regularCap, percent)
  local source = trainer.party or {}
  local target = bossTarget(trainer.classId or trainer.class, challengeCap)
  local ace = 0
  if target then
    for _, mon in ipairs(source) do ace = math.max(ace, mon.level or 0) end
  end
  local delta = target and math.max(0, target - ace) or 0
  local rows = trainerRows(data, trainer.classId or trainer.class,
    trainer.member)
  local party = {}
  for index, mon in ipairs(source) do
    local level = target and math.min((mon.level or 1) + delta, target)
      or scaledLevel(mon.level, playerParty, regularCap, percent)
    local row = rows[index]
    local explicitMoves = row and row.moves and #row.moves > 0
    party[index] = rebuild(mon, data, level, false, explicitMoves)
  end
  return party
end

function LevelScaling.install(mod)
  local function enabled()
    return mod.save:get("level_scaling", true) == true
  end

  -- Stored as "percent below the party's best level", in steps of 5.
  local function percentFor(key)
    local value = tonumber(mod.save:get(key, 20)) or 20
    return math.min(math.max(value, 0), 50)
  end

  local function caps(game)
    local challenge = mod.exports.levelCaps.current(game)
    local regular = mod.save:get("level_caps", true) == true
      and challenge or nil
    return challenge, regular
  end

  local pendingWildLevel
  local repelSuppresses = World.repelSuppresses
  assert(type(repelSuppresses) == "function",
    "Gold Repel level scaling is unavailable; update this mod")
  World.repelSuppresses = function(world, level, ...)
    pendingWildLevel = nil
    if not enabled() then return repelSuppresses(world, level, ...) end
    local game = world and world.game or mod.game
    local _, cap = caps(game)
    local scaled = scaledLevel(level,
      game and game.save and game.save.party, cap,
      percentFor("wild_scaling_percent"))
    local suppressed = repelSuppresses(world, scaled, ...)
    if not suppressed then
      pendingWildLevel = { vanilla = level, scaled = scaled }
    end
    return suppressed
  end

  mod.hooks:wrap("trainer.party", function(next, classId, member, party)
    local result = next(classId, member, party) or party
    if not enabled() then return result end
    local game = mod.game
    local challengeCap, regularCap = caps(game)
    return scaledTrainerParty({ classId = classId, member = member,
        party = result },
      game and game.save and game.save.party, game and game.data,
      challengeCap, regularCap, percentFor("trainer_scaling_percent"))
  end, 1000)

  local battleNew = Battle.new
  Battle.new = function(opts)
    opts = opts or {}
    if enabled() then
      local game = mod.game
      local _, cap = caps(game)
      if opts.wild then
        local level
        if pendingWildLevel
            and pendingWildLevel.vanilla == opts.wild.level then
          level = pendingWildLevel.scaled
        else
          level = scaledLevel(opts.wild.level, opts.party, cap,
            percentFor("wild_scaling_percent"))
        end
        pendingWildLevel = nil
        opts.wild = rebuild(opts.wild, opts.data,
          level, opts.roaming ~= nil, false)
      end
    end
    if not opts.wild then pendingWildLevel = nil end
    return battleNew(opts)
  end
end

return LevelScaling
