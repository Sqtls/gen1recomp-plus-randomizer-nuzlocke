-- Item randomization for the four ways a script hands the player an item:
-- itemballs (HiddenItems.ballPickupScript), hidden items
-- (HiddenItems.pickupScript), NPC gifts and the gym leaders' TM rewards.  All
-- four reach the VM as `giveitem` / `verbosegiveitem` rows, so one
-- `script.command` wrapper covers them; `getitemname` is rewritten with the
-- SAME key because the hidden-item and itemball scripts name the item before
-- they give it (src/world/gen2/HiddenItems.lua).
--
-- KEY_ITEM pocket items and HMs are never touched: they gate progression, and
-- the run would be unfinishable without them.
local ItemRandomizer = {}

local World = require("src.world.gen2.World")

local function setting(mod, key, default)
  local value = mod.save:get(key)
  if value == nil then return default end
  return value
end

local function hash(seed, value)
  local result = tonumber(seed) or 1
  for index = 1, #value do
    result = (result * 131 + value:byte(index)) % 2147483647
  end
  return result
end

-- Ids the extractor emits for ItemNames rows the cart never uses (ITEM_19,
-- ITEM_2D, ...); ITEMFINDER has no underscore, so it is not caught here.
-- PARK_BALL only works inside the Bug Contest and NO_ITEM is the empty slot.
local function usable(def)
  return def and def.id and not def.id:match("^ITEM_")
    and def.id ~= "NO_ITEM" and def.id ~= "PARK_BALL"
end

local function isTm(def) return def.id:match("^TM_") ~= nil end
local function isHm(def) return def.id:match("^HM_") ~= nil end

-- Which pool a source item draws from, or nil when it must stay put.
local function categoryOf(def)
  if not usable(def) then return nil end
  if isHm(def) or def.pocket == "KEY_ITEM" then return nil end
  if isTm(def) then return "tm" end
  if def.pocket == "ITEM" or def.pocket == "BALL" then return "item" end
  return nil
end

local pools = setmetatable({}, { __mode = "k" })

local function poolsFor(data)
  local cached = pools[data]
  if cached then return cached end
  local built = { tm = {}, item = {}, byIndex = {} }
  for _, def in pairs(data.items or {}) do
    if type(def) == "table" and type(def.index) == "number" then
      built.byIndex[def.index] = def
      local category = categoryOf(def)
      if category then built[category][#built[category] + 1] = def end
    end
  end
  local function byIndex(left, right) return left.index < right.index end
  table.sort(built.tm, byIndex)
  table.sort(built.item, byIndex)
  pools[data] = built
  return built
end

-- The balanced pool: items whose price sits near the source's, falling back to
-- the sixteen nearest when the window catches nothing.  Price is the only
-- ordering an item has -- there is no BST equivalent -- so a POTION stays a
-- cheap heal and a full restore stays a treat.
local function nearPrice(pool, source)
  local price = source.price or 0
  local window = math.max(200, math.floor(price * 0.5))
  local matched = {}
  for _, def in ipairs(pool) do
    if math.abs((def.price or 0) - price) <= window then
      matched[#matched + 1] = def
    end
  end
  if #matched > 0 then return matched end
  local sorted = {}
  for _, def in ipairs(pool) do sorted[#sorted + 1] = def end
  table.sort(sorted, function(left, right)
    local leftDelta = math.abs((left.price or 0) - price)
    local rightDelta = math.abs((right.price or 0) - price)
    if leftDelta == rightDelta then return left.index < right.index end
    return leftDelta < rightDelta
  end)
  while #sorted > 16 do table.remove(sorted) end
  return sorted
end

local function removeSource(pool, source)
  if #pool <= 1 then return pool end
  local result = {}
  for _, def in ipairs(pool) do
    if def.index ~= source.index then result[#result + 1] = def end
  end
  return #result > 0 and result or pool
end

function ItemRandomizer.install(mod)
  local shared = assert(mod.exports.wildRandomizer,
    "wild randomizer must be installed before item randomizer")

  -- `index` is the raw operand byte the VM reads (cmd.item), not an id.
  local function chooseItem(data, index, mode, scope)
    if mode == "off" or type(index) ~= "number"
        or not (data and data.items) then
      return index
    end
    local built = poolsFor(data)
    local source = built.byIndex[index]
    local category = source and categoryOf(source)
    if not category then return index end
    local pool = built[category]
    if #pool == 0 then return index end
    if mode == "balanced" then pool = nearPrice(pool, source) end
    pool = removeSource(pool, source)
    local key = table.concat({ scope, source.id }, "|")
    local pick = pool[hash(shared.seed(), key) % #pool + 1]
    return (pick and pick.index) or index
  end

  -- Same key for every command of one pickup: the `getitemname` that names the
  -- item and the `giveitem` that hands it over must land on the same result.
  local function scopeOf(ctx, index)
    return table.concat({
      "item", tostring(ctx and ctx.mapId or "UNKNOWN"),
      tostring(ctx and ctx.object or 0), tostring(index),
    }, ":")
  end

  local WATCHED = {
    giveitem = true, verbosegiveitem = true, getitemname = true,
  }

  mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
    local mode = setting(mod, "item_randomizer", "off")
    if mode == "off" or not WATCHED[name] or type(cmd) ~= "table"
        or type(cmd.item) ~= "number" then
      return next(ctx, name, args, cmd)
    end
    local data = mod.game and mod.game.data
    local replacement = chooseItem(data, cmd.item, mode, scopeOf(ctx, cmd.item))
    if replacement == cmd.item then return next(ctx, name, args, cmd) end
    -- A copy, never the cart's own row: the VM keeps decoded script lists and
    -- an edited row would stick for the rest of the run.  `args` is passed
    -- through untouched so the VM does not rebuild the row a second time; it
    -- reads cmd.item ahead of the operand bytes.
    local row = {}
    for key, value in pairs(cmd) do row[key] = value end
    row.item = replacement
    return next(ctx, name, args, row)
  end, 1500)

  -- Berry trees never reach the VM as a `giveitem` row: FruitTreeScript is
  -- transcribed inside the `fruittree` opcode and reads its item straight from
  -- World:fruitTreeItem, so that is where the swap has to happen.
  local fruitTreeItem = World.fruitTreeItem
  assert(type(fruitTreeItem) == "function",
    "Gold berry tree randomization is unavailable; update this mod")
  World.fruitTreeItem = function(world, treeId)
    local index = fruitTreeItem(world, treeId)
    local mode = setting(mod, "item_randomizer", "off")
    if mode == "off" or type(index) ~= "number" or index == 0 then
      return index
    end
    local data = (world and world.game and world.game.data)
      or (mod.game and mod.game.data)
    if not (data and data.items) then return index end
    -- Apricorn trees keep their apricorns: Kurt turns a specific colour into a
    -- specific Ball, and a randomized tree would put that content out of reach.
    local source = poolsFor(data).byIndex[index]
    if source and source.id:match("_APRICORN$") then return index end
    return chooseItem(data, index, mode, "fruittree:" .. tostring(treeId))
  end

  mod.exports.itemRandomizer = {
    chooseItem = chooseItem,
    randomizable = function(def) return categoryOf(def) ~= nil end,
  }
end

return ItemRandomizer
