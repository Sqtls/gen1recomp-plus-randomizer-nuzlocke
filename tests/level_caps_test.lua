local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local hooks = {}
local saved = { level_scaling = false }
local mod = {
  exports = {},
  save = { get = function(_, key, default)
    if saved[key] == nil then return default end
    return saved[key]
  end },
  hooks = { wrap = function(_, name, callback) hooks[name] = callback end },
}

local Mon = {
  growthFor = function() return "MEDIUM" end,
  experienceForLevel = function(_, level) return level * 100 end,
}
package.loaded[table.concat({ "src", "battle", "gen2", "M" .. "on" }, ".")] = Mon
local ItemEffects = {}
function ItemEffects.useOnMon(itemId, mon)
  if itemId == "RARE_CANDY" then
    mon.level = mon.level + 1
    return { used = true, level = mon.level, text = "GREW" }
  end
  return { used = true }
end
package.loaded[table.concat(
  { "src", "core", "gen2", "Item" .. "Effects" }, ".")] = ItemEffects
local Breeding = {}
function Breeding.dayCare(save)
  save.dayCare = save.dayCare or { man = {}, lady = {} }
  return save.dayCare
end
function Breeding.dayCareStep(_, save)
  local dayCare = Breeding.dayCare(save)
  for _, side in ipairs({ dayCare.man, dayCare.lady }) do
    if side.mon then side.mon.experience = side.mon.experience + 200 end
  end
  return true
end
function Breeding.withdraw(_, save, which)
  local side = Breeding.dayCare(save)[which]
  local mon = side and side.mon
  if not mon then return false end
  mon.level = math.floor(mon.experience / 100)
  save.party = save.party or {}
  save.party[#save.party + 1] = mon
  side.mon = nil
  return true, mon, 100
end
package.loaded[table.concat(
  { "src", "core", "gen2", "Breed" .. "ing" }, ".")] = Breeding

local feature = assert(loadfile(root .. "/features/level_caps.lua"))()
feature.install(mod)

local current = mod.exports.levelCaps.current
local cap, target = current({ save = { player = { badges = {} } } })
eq(cap, 9, "a new run is capped for Falkner")
eq(target, "FALKNER", "a new run names Falkner as its target")

local function withJohto(...)
  local badges = {}
  for _, badge in ipairs({ ... }) do badges[badge] = true end
  return { save = { player = { badges = badges } } }
end

local johto = {
  { { "ZEPHYR" }, 16, "BUGSY" },
  { { "ZEPHYR", "HIVE" }, 20, "WHITNEY" },
  { { "ZEPHYR", "HIVE", "PLAIN" }, 25, "MORTY" },
  { { "ZEPHYR", "HIVE", "PLAIN", "FOG" }, 30, "CHUCK" },
  { { "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM" }, 31, "PRYCE" },
  { { "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM", "GLACIER" },
    35, "JASMINE" },
  { { "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM", "GLACIER",
      "MINERAL" }, 40, "CLAIR" },
}
for _, row in ipairs(johto) do
  cap, target = current(withJohto(unpack(row[1])))
  eq(cap, row[2], "Johto progression advances to " .. row[3])
  eq(target, row[3], "Johto progression names " .. row[3])
end

cap, target = current(withJohto(
  "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM", "MINERAL"))
eq(cap, 31, "beating Jasmine early does not lower or skip Pryce's cap")
eq(target, "PRYCE", "Pryce remains next when Jasmine was beaten early")

cap, target = current({ save = { player = {
  badges = { true, true, true, true, true, true, true },
} } })
eq(cap, 40, "positional badge saves use Gold's native bit order")
eq(target, "CLAIR", "positional badge saves still identify Clair")

local allJohto = {
  ZEPHYR = true, HIVE = true, PLAIN = true, FOG = true,
  STORM = true, GLACIER = true, MINERAL = true, RISING = true,
}
local function postJohto(kanto, hallCount, redEvent)
  local events = {}
  if redEvent then events[236] = 4 end -- EVENT_RED_IN_MT_SILVER (1890)
  return { save = {
    player = { badges = allJohto, kantoBadges = kanto or {} },
    hallOfFame = { count = hallCount or 0, teams = {} },
    events = events,
  } }
end

cap, target = current(postJohto({}, 0))
eq(cap, 50, "Clair unlocks the Elite Four cap")
eq(target, "ELITE FOUR", "the post-Clair target is the Elite Four")

cap, target = current(postJohto({ BOULDER = true, CASCADE = true }, 1))
eq(cap, 50, "Kanto's open-order gyms retain the level 50 cap")
eq(target, "KANTO", "the first seven Kanto badges share one target tier")

local sevenKanto = {
  BOULDER = true, CASCADE = true, THUNDER = true, RAINBOW = true,
  SOUL = true, MARSH = true, VOLCANO = true,
}
cap, target = current(postJohto({
  BOULDER = true, CASCADE = true, THUNDER = true, RAINBOW = true,
  SOUL = true, MARSH = true, VOLCANO = true,
}, 1))
eq(cap, 58, "seven Kanto badges unlock Blue's cap")
eq(target, "BLUE", "seven Kanto badges target Blue")

local allKanto = {
  BOULDER = true, CASCADE = true, THUNDER = true, RAINBOW = true,
  SOUL = true, MARSH = true, VOLCANO = true, EARTH = true,
}
cap, target = current(postJohto(allKanto, 1))
eq(cap, 81, "Blue unlocks Red's cap")
eq(target, "RED", "Blue's badge targets Red")

cap, target = current(postJohto(allKanto, 1, true))
eq(cap, nil, "beating Red removes the level cap")
eq(target, "COMPLETE", "beating Red completes the cap schedule")

saved.level_scaling = true
cap, target = current(postJohto({}, 1))
eq(cap, 52, "scaling raises the first Kanto challenge cap to 52")
cap = current(postJohto({ BOULDER = true }, 1))
eq(cap, 55, "one Kanto badge raises the next scaling cap to 55")
cap = current(postJohto({
  BOULDER = true, CASCADE = true, THUNDER = true,
  RAINBOW = true, SOUL = true, MARSH = true,
}, 1))
eq(cap, 70, "six Kanto badges raise the final open-order leader cap to 70")
cap, target = current(postJohto(sevenKanto, 1))
eq(cap, 75, "seven Kanto badges raise Blue's scaling cap to 75")
eq(target, "BLUE", "the level 75 scaling tier targets Blue")
saved.level_scaling = false

mod.game = { save = { player = { badges = {} } }, data = { pokemon = {
  CYNDAQUIL = { growthRate = "MEDIUM" },
} } }
local expGain = hooks["exp.gain"]
eq(type(expGain), "function", "battle EXP enforcement is installed")
local learner = { species = "CYNDAQUIL", level = 8, experience = 850 }
local gained = expGain(function() return 200 end, { mon = learner })
eq(gained, 50, "battle EXP is trimmed to the active cap threshold")
learner.level, learner.experience = 9, 900
gained = expGain(function() return 200 end, { mon = learner })
eq(gained, 0, "a Pokemon at the cap gains zero battle EXP")

mod.game.save.player.badges.ZEPHYR = true
gained = expGain(function() return 200 end, { mon = learner })
eq(gained, 200, "battle EXP resumes immediately after the cap advances")
mod.game.save.player.badges.ZEPHYR = nil

saved.level_caps = false
gained = expGain(function() return 200 end, { mon = learner })
eq(gained, 200, "disabling level caps restores normal battle EXP")
saved.level_caps = true

learner.level, learner.experience = 9, 900
local candy = ItemEffects.useOnMon("RARE_CANDY", learner, mod.game.data)
eq(candy.used, false, "Rare Candy is refused at the active cap")
eq(learner.level, 9, "a refused Rare Candy does not raise the level")
eq(candy.text, "The level cap is\nlevel 9!",
  "Rare Candy refusal explains the current cap")

learner.level, learner.experience = 8, 850
candy = ItemEffects.useOnMon("RARE_CANDY", learner, mod.game.data)
eq(candy.used, true, "Rare Candy still works below the cap")
eq(learner.level, 9, "Rare Candy may raise a Pokemon exactly to the cap")

saved.level_caps = false
candy = ItemEffects.useOnMon("RARE_CANDY", learner, mod.game.data)
eq(candy.used, true, "disabled caps restore normal Rare Candy use")
eq(learner.level, 10, "disabled caps allow a Rare Candy past the old cap")
saved.level_caps = true

local daycareSave = {
  player = { badges = {} }, party = {},
  dayCare = { man = { mon = {
    species = "CYNDAQUIL", level = 8, experience = 850,
  } }, lady = {} },
}
mod.game.save = daycareSave
Breeding.dayCareStep(mod.game.data, daycareSave)
eq(daycareSave.dayCare.man.mon.experience, 900,
  "Day Care steps stop at the active cap threshold")

daycareSave.player.badges.ZEPHYR = true
Breeding.dayCareStep(mod.game.data, daycareSave)
eq(daycareSave.dayCare.man.mon.experience, 1100,
  "Day Care growth resumes when the cap advances")

daycareSave.player.badges.ZEPHYR = nil
daycareSave.dayCare.man.mon.experience = 1200
local withdrawn, daycareMon = Breeding.withdraw(
  mod.game.data, daycareSave, "man")
eq(withdrawn, true, "a capped Day Care Pokemon can still be withdrawn")
eq(daycareMon.level, 9, "Day Care withdrawal cannot cross the active cap")
eq(daycareMon.experience, 900,
  "Day Care withdrawal trims stored experience to the cap threshold")

saved.level_caps = false
daycareSave.dayCare.man.mon = {
  species = "CYNDAQUIL", level = 8, experience = 850,
}
Breeding.dayCareStep(mod.game.data, daycareSave)
eq(daycareSave.dayCare.man.mon.experience, 1050,
  "disabled caps restore normal Day Care growth")
saved.level_caps = true

print("level caps: " .. checks .. " checks passed")
