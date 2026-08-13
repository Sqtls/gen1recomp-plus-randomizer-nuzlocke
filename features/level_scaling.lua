local LevelScaling = {}

local Battle = require("src.battle.gen2.Battle")
local Mon = require("src.battle.gen2.Mon")

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

local function scaledLevel(vanilla, party, cap)
  local random = love and love.math and love.math.random or math.random
  local target = math.floor(highestPartyLevel(party) * 0.8)
    + random(-2, 2)
  return math.min(math.max(vanilla or 1, target), cap or 100)
end

local function rebuild(mon, data, level, preserveHp)
  if not (mon and level > (mon.level or 0)) then return mon end
  return Mon.new(data, mon.species, level, {
    moves = mon.moves,
    item = mon.item,
    dvs = mon.dvs,
    hp = preserveHp and mon.hp or nil,
  }) or mon
end

local function bossTarget(classId, cap)
  if KANTO_LEADERS[classId] or classId == "BLUE" or classId == "RED" then
    return cap
  end
end

local function scaledTrainerParty(trainer, playerParty, data, challengeCap,
    regularCap)
  local source = trainer.party or {}
  local target = bossTarget(trainer.classId or trainer.class, challengeCap)
  local ace = 0
  if target then
    for _, mon in ipairs(source) do ace = math.max(ace, mon.level or 0) end
  end
  local delta = target and math.max(0, target - ace) or 0
  local party = {}
  for index, mon in ipairs(source) do
    local level = target and math.min((mon.level or 1) + delta, target)
      or scaledLevel(mon.level, playerParty, regularCap)
    party[index] = rebuild(mon, data, level)
  end
  return party
end

function LevelScaling.install(mod)
  local function enabled()
    return mod.save:get("level_scaling", true) == true
  end

  local function caps(game)
    local challenge = mod.exports.levelCaps.current(game)
    local regular = mod.save:get("level_caps", true) == true
      and challenge or nil
    return challenge, regular
  end

  mod.hooks:wrap("trainer.party", function(next, classId, member, party)
    local result = next(classId, member, party) or party
    if not enabled() then return result end
    local game = mod.game
    local challengeCap, regularCap = caps(game)
    return scaledTrainerParty({ classId = classId, party = result },
      game and game.save and game.save.party, game and game.data,
      challengeCap, regularCap)
  end, 1000)

  local battleNew = Battle.new
  Battle.new = function(opts)
    opts = opts or {}
    if enabled() then
      local game = mod.game
      local _, cap = caps(game)
      if opts.wild then
        opts.wild = rebuild(opts.wild, opts.data,
          scaledLevel(opts.wild.level, opts.party, cap), opts.roaming ~= nil)
      end
    end
    return battleNew(opts)
  end
end

return LevelScaling
