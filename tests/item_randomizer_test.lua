local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

package.loaded["src.battle.gen2.Encounter"] = {
  treeSet = function() return "FOREST" end,
  treeIsRare = function() return false end,
  treeSlot = function() return nil end,
}
local trees = { [1] = 0, [2] = 0, [3] = 0 }
local World = {
  rockMonEncounter = function() return 0 end,
  fruitTreeItem = function(_, treeId) return trees[treeId] or 0 end,
}
package.loaded["src.world.gen2.World"] = World

local function item(id, index, pocket, price)
  return { id = id, index = index, name = id, pocket = pocket, price = price }
end

local items = {
  MASTER_BALL = item("MASTER_BALL", 1, "BALL", 0),
  POKE_BALL = item("POKE_BALL", 5, "BALL", 200),
  GREAT_BALL = item("GREAT_BALL", 4, "BALL", 600),
  POTION = item("POTION", 18, "ITEM", 300),
  SUPER_POTION = item("SUPER_POTION", 17, "ITEM", 700),
  FULL_RESTORE = item("FULL_RESTORE", 14, "ITEM", 3000),
  RARE_CANDY = item("RARE_CANDY", 32, "ITEM", 4800),
  NUGGET = item("NUGGET", 36, "ITEM", 10000),
  ANTIDOTE = item("ANTIDOTE", 9, "ITEM", 100),
  ESCAPE_ROPE = item("ESCAPE_ROPE", 19, "ITEM", 550),
  REPEL = item("REPEL", 20, "ITEM", 350),
  ETHER = item("ETHER", 63, "ITEM", 1200),
  BERRY = item("BERRY", 173, "ITEM", 200),
  GOLD_BERRY = item("GOLD_BERRY", 174, "ITEM", 300),
  RED_APRICORN = item("RED_APRICORN", 85, "ITEM", 200),
  -- untouchables
  BICYCLE = item("BICYCLE", 7, "KEY_ITEM", 0),
  SECRETPOTION = item("SECRETPOTION", 67, "KEY_ITEM", 0),
  ITEM_19 = item("ITEM_19", 25, "ITEM", 0),
  PARK_BALL = item("PARK_BALL", 177, "BALL", 0),
  TM_MUD_SLAP = item("TM_MUD_SLAP", 191, "TM_HM", 3000),
  TM_HEADBUTT = item("TM_HEADBUTT", 192, "TM_HM", 3000),
  TM_CURSE = item("TM_CURSE", 193, "TM_HM", 3000),
  HM_CUT = item("HM_CUT", 243, "TM_HM", 0),
  HM_SURF = item("HM_SURF", 244, "TM_HM", 0),
}
local data = { items = items, pokemon = {} }

local saved = { randomizer_seed = 321, item_randomizer = "balanced" }
local hooks = {}
local mod = {
  game = { data = data }, exports = {},
  hooks = { wrap = function(_, name, callback, priority)
    hooks[name] = { callback = callback, priority = priority }
  end },
  events = { on = function() end },
  save = {
    get = function(_, key, default)
      if saved[key] == nil then return default end
      return saved[key]
    end,
    set = function(_, key, value) saved[key] = value end,
  },
}

trees[1] = items.BERRY.index
trees[2] = items.RED_APRICORN.index

local wild = assert(loadfile(root .. "/features/wild_randomizer.lua"))()
wild.install(mod)
local randomizer = assert(loadfile(root .. "/features/item_randomizer.lua"))()
randomizer.install(mod)

eq(hooks["script.command"].priority, 1500,
  "item randomization wraps the script VM at the randomizer priority")

-- The VM's own contract: the wrapper hands the row it wants run to `next`.
local function run(name, cmd, ctx)
  local seen
  hooks["script.command"].callback(function(_, _, _, row)
    seen = row
    return nil
  end, ctx or { mapId = "ROUTE_30", object = 2 }, name, cmd.args or {}, cmd)
  return seen
end

local ball = { item = items.POTION.index, quantity = 1 }
local given = run("giveitem", ball)
eq(given.item ~= items.POTION.index, true,
  "BALANCED replaces the item an itemball hands over")
eq(given.quantity, 1, "itemball quantity survives the swap")
eq(ball.item, items.POTION.index, "the cart's own decoded row is not mutated")

local replacement
for _, def in pairs(items) do
  if def.index == given.item then replacement = def end
end
eq(replacement.pocket ~= "KEY_ITEM", true, "replacements are never key items")
eq(math.abs(replacement.price - items.POTION.price) <= 300, true,
  "BALANCED keeps the replacement near the source's price")

eq(run("giveitem", { item = items.POTION.index }).item, given.item,
  "the same map, object and item stay deterministic")
eq(run("getitemname", { item = items.POTION.index }).item, given.item,
  "getitemname names the item giveitem is about to hand over")

local verbose = run("verbosegiveitem", { item = items.TM_MUD_SLAP.index })
eq(verbose.item ~= items.TM_MUD_SLAP.index, true,
  "a gym leader's TM reward is replaced")
local tm
for _, def in pairs(items) do
  if def.index == verbose.item then tm = def end
end
eq(tm.id:match("^TM_") ~= nil, true, "a TM is only ever replaced by another TM")

for _, id in ipairs({ "BICYCLE", "SECRETPOTION", "HM_CUT", "HM_SURF",
    "ITEM_19", "PARK_BALL" }) do
  for seed = 1, 20 do
    saved.randomizer_seed = seed
    eq(run("giveitem", { item = items[id].index }).item, items[id].index,
      id .. " is never randomized")
  end
end
saved.randomizer_seed = 321

-- Nothing may DRAW an untouchable either: HMs, key items, the Bug Contest ball
-- and the unused rows must stay out of every pool.
local forbidden = {
  [items.BICYCLE.index] = true, [items.SECRETPOTION.index] = true,
  [items.HM_CUT.index] = true, [items.HM_SURF.index] = true,
  [items.ITEM_19.index] = true, [items.PARK_BALL.index] = true,
}
saved.item_randomizer = "chaos"
for seed = 1, 200 do
  saved.randomizer_seed = seed
  eq(forbidden[run("giveitem", { item = items.POTION.index }).item], nil,
    "CHAOS never draws a key item, HM, unused row or PARK BALL")
  eq(forbidden[run("verbosegiveitem", { item = items.TM_CURSE.index }).item],
    nil, "CHAOS never replaces a TM with an HM")
end
saved.randomizer_seed = 321

saved.item_randomizer = "off"
eq(run("giveitem", ball), ball, "OFF hands the cart's own row straight through")

saved.item_randomizer = "balanced"
local quest = { item = items.POTION.index }
eq(run("takeitem", quest), quest,
  "takeitem is left alone so quest scripts still balance")
eq(run("checkitem", quest), quest, "checkitem is left alone")

local other = run("giveitem", { item = items.POTION.index },
  { mapId = "ROUTE_31", object = 2 })
eq(other.item ~= given.item, true,
  "the same item on another map rolls its own replacement")

local picked = World.fruitTreeItem({}, 1)
eq(picked ~= items.BERRY.index, true, "a berry tree's fruit is randomized")
eq(World.fruitTreeItem({}, 1), picked, "one tree keeps one fruit for the run")
eq(World.fruitTreeItem({}, 2), items.RED_APRICORN.index,
  "APRICORN trees keep their apricorn so Kurt's Balls stay reachable")
eq(World.fruitTreeItem({}, 3), 0, "an empty tree stays empty")
saved.item_randomizer = "off"
eq(World.fruitTreeItem({}, 1), items.BERRY.index,
  "OFF leaves berry trees alone")
saved.item_randomizer = "balanced"

print(("item randomizer: %d checks passed"):format(checks))
