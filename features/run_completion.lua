local RunCompletion = {}
local COMPLETE_SCREEN = "Gen1RecompPlusNuzlockeComplete"

function RunCompletion.install(mod)
  local pending = setmetatable({}, { __mode = "k" })
  local shown = setmetatable({}, { __mode = "k" })

  mod.content.screens:register(COMPLETE_SCREEN, {
    new = function(game)
      return mod.exports.runReport.newCompletedScreen(game)
    end,
  })

  local function show(game)
    if not game or shown[game] then return end
    shown[game] = true
    mod.ui.push(game, COMPLETE_SCREEN)
  end

  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    local trainer = battle and battle.trainer
    local isRed = trainer
      and (trainer.classId == "RED" or trainer.class == "RED")
    if ev and ev.result == "win" and isRed
        and mod.save:get("nuzlocke_started") == true
        and mod.save:get("nuzlocke_completed") ~= true then
      mod.save:set("nuzlocke_completed", true)
      pending[battle] = true
    end
  end)

  mod.events:on("save.created", function()
    mod.save:set("nuzlocke_completed", nil)
  end)

  local BattleState = require("src.ui.gen2.BattleState")
  local finishBattle = BattleState.finishBattle
  assert(type(finishBattle) == "function",
    "Gold BattleState.finishBattle is unavailable; update this mod")
  BattleState.finishBattle = function(screen, ...)
    local battle = screen and screen.battle
    if not (battle and pending[battle]) then
      return finishBattle(screen, ...)
    end
    pending[battle] = nil
    local onDone = screen.onDone
    local completed = false
    local function complete(...)
      if completed then return end
      completed = true
      local result
      if onDone then result = onDone(...) end
      show(screen.game or mod.game)
      return result
    end
    screen.onDone = complete
    local result = finishBattle(screen, ...)
    complete()
    return result
  end
end

return RunCompletion
