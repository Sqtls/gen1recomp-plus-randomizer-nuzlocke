local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

local BattleState = {
  finishBattle = function(screen)
    if screen.onDone then return screen.onDone() end
  end,
}
local battleStateModule = table.concat({ "src", "ui", "gen2", "BattleState" }, ".")
package.loaded[battleStateModule] = BattleState

local saved = { nuzlocke_started = true }
local listeners = {}
local screens = {}
local pushed = {}
local reportGame
local mod = {
  game = { save = {} },
  exports = {
    runReport = {
      newCompletedScreen = function(game)
        reportGame = game
        return { title = "NUZLOCKE COMPLETE" }
      end,
    },
  },
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  events = {
    on = function(_, event, callback)
      listeners[event] = listeners[event] or {}
      listeners[event][#listeners[event] + 1] = callback
    end,
  },
  content = {
    screens = {
      register = function(_, id, factory) screens[id] = factory end,
    },
  },
  ui = {
    push = function(game, id)
      pushed[#pushed + 1] = { game = game, id = id }
    end,
  },
}
local function emit(event, payload)
  for _, callback in ipairs(listeners[event] or {}) do callback(payload) end
end

local feature = assert(loadfile(root .. "/features/run_completion.lua"))()
feature.install(mod)

local ordinary = { trainer = { classId = "YOUNGSTER" } }
emit("battle.ended", { battle = ordinary, result = "win" })
BattleState.finishBattle({ battle = ordinary, game = mod.game })
eq(saved.nuzlocke_completed, nil, "ordinary trainer wins do not finish the run")
eq(#pushed, 0, "ordinary trainer wins do not show completion")

local lostToRed = { trainer = { classId = "RED" } }
emit("battle.ended", { battle = lostToRed, result = "lose" })
BattleState.finishBattle({ battle = lostToRed, game = mod.game })
eq(saved.nuzlocke_completed, nil, "losing to Red does not finish the run")

local red = { trainer = { classId = "RED" } }
emit("battle.ended", { battle = red, result = "win" })
eq(saved.nuzlocke_completed, true,
  "defeating Red permanently marks the run complete")
eq(#pushed, 0, "completion waits for the battle screen to finish")
local originalDone = false
BattleState.finishBattle({
  battle = red, game = mod.game,
  onDone = function() originalDone = true end,
})
eq(originalDone, true, "Red's normal post-battle callback still runs")
eq(#pushed, 1, "completion appears after Red's battle screen finishes")
eq(pushed[1].id, "Gen1RecompPlusNuzlockeComplete",
  "Red victory opens the dedicated completion screen")

local built = screens.Gen1RecompPlusNuzlockeComplete.new(mod.game)
eq(built.title, "NUZLOCKE COMPLETE",
  "completion screen delegates to the run report")
eq(reportGame, mod.game, "completion report receives the active game")

local rematch = { trainer = { class = "RED" } }
emit("battle.ended", { battle = rematch, result = "win" })
BattleState.finishBattle({ battle = rematch, game = mod.game })
eq(#pushed, 1, "Red rematches cannot trigger completion twice")

emit("save.created", {})
eq(saved.nuzlocke_completed, nil,
  "a brand-new run clears the prior completion marker")

print(("run completion: %d checks passed"):format(checks))
