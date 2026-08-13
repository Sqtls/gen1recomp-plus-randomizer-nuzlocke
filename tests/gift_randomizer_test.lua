local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local saved = {
  gift_randomizer = "chaos", gift_legendaries = "exclude",
  randomizer_seed = 77,
}
local pokemon = {
  EEVEE = { index = 133, name = "EEVEE", evolutions = {} },
  PIKACHU = { index = 25, name = "PIKACHU", evolutions = {} },
  TOGEPI = { index = 175, name = "TOGEPI", evolutions = {
    { into = "TOGETIC" } }, eggGroupsRaw = 0x11, eggSteps = 10 },
  CLEFFA = { index = 173, name = "CLEFFA", evolutions = {
    { into = "CLEFAIRY" } }, eggGroupsRaw = 0x88, eggSteps = 10 },
  SHUCKLE = { index = 213, name = "SHUCKLE", evolutions = {} },
  HERACROSS = { index = 214, name = "HERACROSS", evolutions = {} },
  ABRA = { index = 63, name = "ABRA", evolutions = {
    { into = "KADABRA" } } },
  GASTLY = { index = 92, name = "GASTLY", evolutions = {
    { into = "HAUNTER" } } },
  LUGIA = { index = 249, name = "LUGIA", evolutions = {},
    eggGroupsRaw = 0xff },
}
local data = { pokemon = pokemon }
local game = {
  data = data,
  save = { party = {}, pokedex = { seen = {}, caught = {} } },
}
local currentMap = "GOLDENROD_CITY"

local World = { load = function(world)
  world.vm = {
    giveEggFn = function(index, level)
      for species, def in pairs(pokemon) do
        if def.index == index then
          game.save.party[#game.save.party + 1] = {
            species = species, level = level, isEgg = true,
          }
          return true
        end
      end
      return false
    end,
  }
  return true
end }
package.loaded["src.world.gen2.World"] = World

local PrizeMenu = {}
function PrizeMenu:buildPrizes()
  self.prizes = {}
  for index, prize in ipairs(self.counter.prizes or {}) do
    self.prizes[index] = prize
  end
  self.prizes[#self.prizes + 1] = { cancel = true, label = "CANCEL" }
end
package.loaded["src.ui.gen2.PrizeMenu"] = PrizeMenu

local function giveShuckle(vm)
  game.save.party[#game.save.party + 1] = {
    species = "SHUCKLE", level = 15, nickname = "SHUCKIE",
    item = "BERRY", ot = "MANIA", otId = 518, happiness = 70,
  }
  vm.scriptVar = 1
end
local function returnShuckle(vm) vm.vanillaReturn = true end
local Specials = {
  MANIA_OT = "MANIA", MANIA_OT_ID = 518,
  SHUCKIE_HAPPY_THRESHOLD = 150,
  SHUCKIE_WRONG_MON = 0, SHUCKIE_REFUSED = 1, SHUCKIE_RETURNED = 2,
  SHUCKIE_HAPPY = 3, SHUCKIE_FAINTED = 4,
  ALL = { GiveShuckle = giveShuckle, ReturnShuckie = returnShuckle },
  HANDLERS = { GiveShuckle = giveShuckle, ReturnShuckie = returnShuckle },
}
function Specials.block(_, start)
  local result
  start(function(value) result = value end)
  return result
end
package.loaded["src.script.gen2.Specials"] = Specials

local Mon = {}
function Mon.new(_, species, level, opts)
  return { species = species, level = level, nickname = opts and opts.nickname,
    item = opts and opts.item, dvs = opts and opts.dvs, hp = 10,
    happiness = opts and opts.happiness or 70 }
end
package.loaded["src.battle.gen2.Mon"] = Mon

local Breeding = { hatch = function(_, save, index)
  local egg = save.party[index]
  local mon = { species = egg.species }
  save.party[index] = mon
  return mon, { species = egg.species, togepi = egg.species == "TOGEPI" }
end }
function Breeding.isNoEggs(definition)
  return not definition or definition.eggGroupsRaw == 0xff
end
package.loaded["src.core.gen2.Breeding"] = Breeding

local listeners = {}
local replacements = {
  EEVEE = "PIKACHU", TOGEPI = "CLEFFA", SHUCKLE = "HERACROSS",
  ABRA = "GASTLY",
}
local mod = {
  game = game,
  exports = { wildRandomizer = {
    chooseSpecies = function(_, source, mode, scope, slot, allowed)
      local replacement = replacements[source] or source
      if allowed and not allowed(replacement) then return source end
      return replacement
    end,
    legendary = function(species) return species == "LUGIA" end,
  } },
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

local feature = assert(loadfile(root .. "/features/gift_randomizer.lua"))()
feature.install(mod)

local gift = { game = game, world = { map = { id = "GOLDENROD_CITY" } },
  species = "EEVEE", level = 20, source = "script" }
listeners["pokemon.before_give"](gift)
eq(gift.species, "PIKACHU", "scripted gift species is randomized")
eq(gift.level, 20, "scripted gift keeps its authored level")

local starter = { game = game, world = { map = { id = "ELMS_LAB" } },
  species = "CYNDAQUIL", level = 5, source = "script" }
listeners["pokemon.before_give"](starter)
eq(starter.species, "CYNDAQUIL",
  "Elm starters remain owned by the starter randomizer")

local world = { game = game }
eq(World.load(world), true, "gift randomizer preserves world loading")
eq(world.vm.giveEggFn(175, 5), true, "randomized scripted Egg is granted")
eq(game.save.party[#game.save.party].species, "CLEFFA",
  "Togepi Egg becomes a hatchable randomized species")
local eggIndex = #game.save.party
local _, hatchEffects = Breeding.hatch(data, game.save, eggIndex)
eq(hatchEffects.togepi, true,
  "randomized Togepi Egg preserves the story hatch event")

replacements.EEVEE = "LUGIA"
eq(mod.exports.giftRandomizer.choose(data, "EEVEE", "legend-test", false),
  "EEVEE", "legendary gift replacements are excluded by default")
saved.gift_legendaries = "allow"
eq(mod.exports.giftRandomizer.choose(data, "EEVEE", "legend-test", false),
  "LUGIA", "legendary gift replacements can be allowed")
saved.gift_legendaries = "exclude"
replacements.EEVEE = "PIKACHU"

replacements.TOGEPI = "LUGIA"
eq(mod.exports.giftRandomizer.choose(data, "TOGEPI", "egg-test", true),
  "TOGEPI", "scripted Eggs cannot become unhatchable legendaries")
replacements.TOGEPI = "CLEFFA"

local menu = { game = game, data = data, counter = { kind = "mon", prizes = {
  { id = "ABRA", label = "ABRA        200", cost = 200, level = 10 },
} } }
PrizeMenu.buildPrizes(menu)
eq(menu.prizes[1].id, "GASTLY", "Game Corner prize species is randomized")
eq(menu.prizes[1].cost, 200, "Game Corner prize keeps its authored price")
eq(menu.prizes[1].level, 10, "Game Corner prize keeps its authored level")
eq(menu.prizes[1].label:find("GASTLY", 1, true) ~= nil, true,
  "Game Corner menu names the randomized prize")
eq(#menu.prizes[1].label, 15,
  "Game Corner menu keeps the original row width")

game.save.party = {}
local vm = { specials = {
  party = function() return game.save.party end,
  data = function() return data end,
  selectPartyMon = function(_, onDone)
    onDone(1, game.save.party[1])
  end,
} }
Specials.ALL.GiveShuckle(vm)
eq(game.save.party[1].species, "HERACROSS", "Shuckie is randomized")
eq(game.save.party[1].nickname, "SHUCKIE",
  "randomized Shuckie keeps its fixed nickname")
eq(game.save.party[1].ot, "MANIA", "randomized Shuckie keeps Mania's OT")
Specials.ALL.ReturnShuckie(vm)
eq(#game.save.party, 0, "Mania accepts the randomized Shuckie back")
eq(vm.scriptVar, Specials.SHUCKIE_RETURNED,
  "randomized Shuckie return reports the vanilla result")
eq(vm.shuckieHappiness, 70,
  "randomized Shuckie return preserves Mania's happiness reading")

Specials.ALL.GiveShuckle(vm)
game.save.party[1].happiness = 150
Specials.ALL.ReturnShuckie(vm)
eq(#game.save.party, 1, "Mania lets a happy randomized Shuckie stay")
eq(vm.scriptVar, Specials.SHUCKIE_HAPPY,
  "happy randomized Shuckie reports the vanilla result")
game.save.party = {}

saved.gift_randomizer = "off"
local vanillaGift = { game = game,
  world = { map = { id = "GOLDENROD_CITY" } }, species = "EEVEE" }
listeners["pokemon.before_give"](vanillaGift)
eq(vanillaGift.species, "EEVEE", "OFF preserves scripted gifts")

print(("gift randomizer: %d checks passed"):format(checks))
