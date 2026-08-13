local MandatoryNicknames = {}

local function normalized(name)
  return tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
end

function MandatoryNicknames.install(mod)
  local function enabled()
    return mod.save:get("mandatory_nicknames", true) == true
  end

  mod.hooks:wrap("pokemon.nickname", function(next, ctx)
    local required, defaultName = next(ctx)
    return enabled() and true or required, defaultName
  end, 1000)

  local NamingScreen = require("src.ui.gen2.NamingScreen")
  local newNamingScreen = NamingScreen.new
  local acceptName = NamingScreen.accept
  assert(type(newNamingScreen) == "function" and type(acceptName) == "function",
    "Gold NamingScreen nickname enforcement is unavailable; update this mod")

  NamingScreen.new = function(game, opts)
    local screen = newNamingScreen(game, opts)
    if enabled() and opts and opts.type == "nickname" then
      screen.nuzlockeNicknameRequired = true
    end
    return screen
  end

  NamingScreen.accept = function(screen, ...)
    if screen.nuzlockeNicknameRequired then
      local entered = normalized(screen.text)
      if entered == "" or entered == normalized(screen.monName) then return end
    end
    return acceptName(screen, ...)
  end

  local BattleState = require("src.ui.gen2.BattleState")
  local askNickname = BattleState.askNickname
  assert(type(askNickname) == "function",
    "Gold caught-Pokemon nickname enforcement is unavailable; update this mod")

  BattleState.askNickname = function(screen, mon, ...)
    if enabled() then
      screen.nicknameMon = mon
      return screen:answerNickname(true)
    end
    return askNickname(screen, mon, ...)
  end

  local World = require("src.world.gen2.World")
  local loadWorld = World.load
  local askYesNo = World.askYesNo
  assert(type(loadWorld) == "function" and type(askYesNo) == "function",
    "Gold overworld nickname enforcement is unavailable; update this mod")

  World.load = function(world, ...)
    local result = loadWorld(world, ...)
    local vm = world.vm
    local givePoke = vm and vm.givePokeFn
    if type(givePoke) ~= "function" then return result end

    vm.givePokeFn = function(...)
      local save = world.game and world.game.save
      local before = #(save and save.party or {})
      local gift = givePoke(...)
      -- Newer engines return this record and make the VM perform the same
      -- blocking nickname flow through pokemon.nickname. v0.1.80 returns nil.
      if not enabled() or type(gift) == "table" and gift.mon then return gift end

      local party = save and save.party or {}
      local mon = #party > before and party[#party] or nil
      if not mon then return gift end

      local finished = false
      local opened = world:renameMon(mon, function(name)
        if normalized(name) ~= ""
            and normalized(name) ~= normalized(mon.name or mon.species) then
          mon.nickname = name
        end
        finished = true
        if vm.co and coroutine.status(vm.co) == "suspended" then vm:resume() end
      end, { blank = true })
      if opened and not finished and coroutine.running() then
        coroutine.yield({ kind = "mandatory-nickname" })
      end
      return gift
    end
    return result
  end

  World.askYesNo = function(world, onChoose, ...)
    local prompt = tostring(world and world.lastText or "")
    if enabled() and prompt:match("^Give a nickname to[%s%c]") then
      local held = world.stayedTextBox
      if held then
        world.stayedTextBox = nil
        held.stay = nil
        local stack = world.game and world.game.stack
        if stack and stack:top() == held then stack:pop() end
        world.textbox = nil
      end
      world.choicebox = nil
      if onChoose then onChoose(true) end
      return
    end
    return askYesNo(world, onChoose, ...)
  end
end

return MandatoryNicknames
