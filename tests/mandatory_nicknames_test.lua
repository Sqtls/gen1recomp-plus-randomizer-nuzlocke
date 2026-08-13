local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local hookChains = {}
local saved = {}
local mod = {
  hooks = {
    wrap = function(_, name, callback) hookChains[name] = callback end,
  },
  save = {
    get = function(_, key, default)
      if saved[key] == nil then return default end
      return saved[key]
    end,
  },
}

local NamingScreen = { TYPES = { nickname = {} } }
NamingScreen.__index = NamingScreen
function NamingScreen.new(_, opts)
  return setmetatable({
    kind = NamingScreen.TYPES[opts.type],
    monName = opts.monName,
    text = opts.initial or "",
    onDone = opts.onDone,
  }, NamingScreen)
end
function NamingScreen:accept()
  if self.onDone then self.onDone(self.text) end
end

local BattleState = {}
function BattleState:askNickname(mon)
  self.optionalNicknamePrompt = mon
end
function BattleState:answerNickname(answer)
  self.forcedNicknameAnswer = answer
end

local asked = {}
local World = {}
function World:load()
  self.game = { save = { party = {} } }
  self.vm = {
    givePokeFn = function()
      self.game.save.party[1] = { species = "CYNDAQUIL" }
    end,
  }
end
function World:renameMon(mon, onDone, opts)
  self.renamedMon = mon
  self.renameOpts = opts
  self.finishRename = onDone
  return true
end
function World:askYesNo(onChoose)
  asked[#asked + 1] = self.lastText
  onChoose(false)
end

local namingModule = table.concat({ "src", "ui", "gen2", "Naming" .. "Screen" }, ".")
local battleModule = table.concat({ "src", "ui", "gen2", "Battle" .. "State" }, ".")
local worldModule = table.concat({ "src", "world", "gen2", "World" }, ".")
package.loaded[namingModule] = NamingScreen
package.loaded[battleModule] = BattleState
package.loaded[worldModule] = World

local feature = assert(loadfile(root .. "/features/mandatory_nicknames.lua"))()
feature.install(mod)

local legacyWorld = setmetatable({}, { __index = World })
legacyWorld:load()
local starterFinished = false
local starterFlow = coroutine.create(function()
  legacyWorld.vm.givePokeFn(155, 5, 0)
  starterFinished = true
end)
legacyWorld.vm.co = starterFlow
legacyWorld.vm.resume = function(self)
  local ok, err = coroutine.resume(self.co)
  assert(ok, err)
end
local ok, err = coroutine.resume(starterFlow)
assert(ok, err)
eq(legacyWorld.renamedMon and legacyWorld.renamedMon.species, "CYNDAQUIL",
  "legacy Gold starter path must open nickname entry")
eq(legacyWorld.renameOpts and legacyWorld.renameOpts.blank, true,
  "legacy starter nickname entry starts blank")
eq(starterFinished, false, "legacy starter script waits for nickname entry")
legacyWorld.finishRename("EMBER")
eq(legacyWorld.game.save.party[1].nickname, "EMBER",
  "legacy starter stores the required nickname")
eq(starterFinished, true, "legacy starter script resumes after naming")

local caught = { species = "SENTRET" }
local battleScreen = setmetatable({}, { __index = BattleState })
battleScreen:askNickname(caught)
eq(battleScreen.forcedNicknameAnswer, true,
  "legacy Gold catch path must open nickname entry")
eq(battleScreen.optionalNicknamePrompt, nil,
  "legacy Gold catch path must skip the optional yes/no prompt")

local nicknameHook = hookChains["pokemon.nickname"]
eq(type(nicknameHook), "function", "mandatory nickname hook is installed")
local required, defaultName = nicknameHook(function()
  return false, "CYNDAQUIL"
end, { source = "gift" })
eq(required, true, "starter and gift naming is required")
eq(defaultName, "CYNDAQUIL", "engine default name is preserved")

saved.mandatory_nicknames = false
required = nicknameHook(function() return true end, { source = "catch" })
eq(required, true, "disabled setting preserves another required-name rule")
saved.mandatory_nicknames = true

local completed
local screen = NamingScreen.new({}, {
  type = "nickname",
  monName = "CYNDAQUIL",
  onDone = function(name) completed = name end,
})

screen.text = ""
screen:accept()
eq(completed, nil, "blank nickname cannot finish")

screen.text = "  Cyndaquil  "
screen:accept()
eq(completed, nil, "species default cannot finish")

screen.text = "EMBER"
screen:accept()
eq(completed, "EMBER", "custom nickname finishes normally")

local nicknameAnswer
World.askYesNo({ lastText = "Give a nickname to\nTOGEPI?" }, function(answer)
  nicknameAnswer = answer
end)
eq(nicknameAnswer, true, "egg nickname prompt is forced to yes")
eq(#asked, 0, "forced egg prompt does not open a yes/no choice")

World.askYesNo({
  lastText = "Give a nickname to\nthe SCYTHER you\nreceived?",
}, function(answer)
  nicknameAnswer = answer
end)
eq(nicknameAnswer, true, "Contest reward nickname prompt is forced to yes")
eq(#asked, 0, "forced Contest prompt does not open a yes/no choice")

local held = { stay = {} }
local popped
World.askYesNo({
  lastText = "Give a nickname to\nthe SCYTHER you\nreceived?",
  stayedTextBox = held,
  game = { stack = {
    top = function() return held end,
    pop = function() popped = true end,
  } },
}, function() end)
eq(popped, true, "Contest question box closes before nickname entry")
eq(held.stay, nil, "Contest question releases its held text box")

local ordinaryAnswer
World.askYesNo({ lastText = "Use CUT?" }, function(answer)
  ordinaryAnswer = answer
end)
eq(ordinaryAnswer, false, "unrelated yes/no prompts keep engine behavior")
eq(asked[1], "Use CUT?", "ordinary prompt still reaches the engine")

print("mandatory nickname tests: " .. checks .. " checks passed")
