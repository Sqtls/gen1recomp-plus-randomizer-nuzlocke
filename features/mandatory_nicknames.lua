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

  local World = require("src.world.gen2.World")
  local askYesNo = World.askYesNo
  assert(type(askYesNo) == "function",
    "Gold overworld nickname enforcement is unavailable; update this mod")

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
