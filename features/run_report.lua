local RunReport = {}

local function setting(mod, key, default)
  local value = mod.save:get(key)
  if value == nil then return default end
  return value
end

function RunReport.install(mod)
  local recordedDeaths = setmetatable({}, { __mode = "k" })

  local function active()
    return mod.save:get("nuzlocke_started") == true
  end

  local function locationForMap(game, mapId)
    local maps = game and game.data and game.data.gen2Maps
    local landmarks = game and game.data and game.data.landmarks
    local landmark = maps and maps[mapId] and maps[mapId].landmark
    local name = landmarks and landmarks[landmark] and landmarks[landmark].name
    return tostring(name or mapId):gsub("\n", " "):gsub("_", " ")
  end

  local function location(game)
    local current = mod.world:current()
    return locationForMap(game, current and current.mapId or "UNKNOWN")
  end

  local function append(key, record)
    local journal = mod.save:get(key)
    if type(journal) ~= "table" then journal = {} end
    journal[#journal + 1] = record
    mod.save:set(key, journal)
  end

  local function recordDeath(game, mon)
    if not mon or recordedDeaths[mon] then return end
    recordedDeaths[mon] = true
    append("run_deaths", {
      species = mon.species,
      name = mon.nickname or mon.species,
      level = mon.level,
      location = location(game),
    })
  end

  mod.events:on("save.created", function()
    mod.save:set("run_journal_version", 1)
    mod.save:set("run_history_incomplete", nil)
    mod.save:set("run_catches", {})
    mod.save:set("run_deaths", {})
  end)

  mod.events:on("save.loaded", function()
    if mod.save:get("run_journal_version") ~= nil then return end
    if active() then mod.save:set("run_history_incomplete", true) end
    mod.save:set("run_journal_version", 1)
  end)

  local function countTrue(values)
    local count = 0
    for _, value in pairs(values or {}) do
      if value then count = count + 1 end
    end
    return count
  end

  local function encounterEntries(game)
    local entries = {}
    local catches = mod.save:get("run_catches")
    local areas = mod.save:get("encounter_areas") or {}
    if type(catches) == "table" then
      for _, caught in ipairs(catches) do
        entries[#entries + 1] = {
          top = "CAUGHT " .. tostring(caught.name or caught.species),
          bottom = caught.location or "UNKNOWN",
        }
      end
    else
      local keys = {}
      for key, area in pairs(areas) do
        if area.status == "caught" then keys[#keys + 1] = key end
      end
      table.sort(keys)
      for _, key in ipairs(keys) do
        local area = areas[key]
        entries[#entries + 1] = {
          top = "CAUGHT " .. tostring(area.species or "POK\195\169MON"),
          bottom = locationForMap(game, area.mapId or "UNKNOWN"),
        }
      end
    end

    local failed = {}
    for key, area in pairs(areas) do
      if area.status == "failed" then failed[#failed + 1] = key end
    end
    table.sort(failed)
    for _, key in ipairs(failed) do
      local area = areas[key]
      local reasons = {
        run = "RAN", fled = "FLED", lose = "LOST",
        duplicate = "DUPE", ended = "KO", win = "KO",
      }
      local reason = reasons[area.result] or "FAILED"
      entries[#entries + 1] = {
        top = ("%s: %s"):format(reason,
          tostring(area.species or "POK\195\169MON")),
        bottom = locationForMap(game, area.mapId or "UNKNOWN"),
      }
    end
    return entries, #failed
  end

  local function memorialEntries()
    local entries = {}
    for _, death in ipairs(mod.save:get("run_deaths") or {}) do
      entries[#entries + 1] = {
        top = ("%s  LV%s"):format(
          tostring(death.name or death.species or "POK\195\169MON"),
          tostring(death.level or "?")),
        bottom = death.location or "UNKNOWN",
      }
    end
    if mod.save:get("run_history_incomplete") == true then
      entries[#entries + 1] = {
        top = "EARLIER LOSSES",
        bottom = "NOT RECORDED",
        incomplete = true,
      }
    end
    return entries
  end

  local function newFailedScreen(game, deleteActiveSave)
    local encounters, failedCount = encounterEntries(game)
    local memorial = memorialEntries()
    local catches = mod.save:get("run_catches")
    local caughtCount = type(catches) == "table" and #catches or 0
    if type(catches) ~= "table" then
      for _, area in pairs(mod.save:get("encounter_areas") or {}) do
        if area.status == "caught" then caughtCount = caughtCount + 1 end
      end
    end
    local save = game and game.save or {}
    local player = save.player or {}
    local time = save.playTime or {}
    local screen = {
      game = game,
      isOpaque = true,
      title = "NUZLOCKE FAILED",
      action = "RESTART GAME",
      page = 1,
      scroll = 1,
      pages = {
        { name = "SUMMARY" },
        { name = "ENCOUNTERS", entries = encounters },
        { name = "MEMORIAL", entries = memorial },
      },
      summary = {
        ("BADGES  %d"):format(countTrue(player.badges)
          + countTrue(player.kantoBadges)),
        ("TIME  %d:%02d"):format(time.hours or 0, time.minutes or 0),
        ("CAUGHT  %d"):format(caughtCount),
        ("FAILED  %d"):format(failedCount),
        ("LOST  %d"):format(#(mod.save:get("run_deaths") or {})),
      },
    }
    if mod.save:get("run_history_incomplete") == true then
      screen.summary[#screen.summary + 1] = "HISTORY PARTIAL"
    end

    local function maxScroll()
      local entries = screen.pages[screen.page].entries or {}
      return math.max(1, #entries - 2)
    end

    function screen:update()
      local input = game.input
      if input:wasPressed("right") then
        self.page = self.page % #self.pages + 1
        self.scroll = 1
      elseif input:wasPressed("left") then
        self.page = (self.page - 2) % #self.pages + 1
        self.scroll = 1
      elseif input:wasPressed("down") then
        self.scroll = math.min(maxScroll(), self.scroll + 1)
      elseif input:wasPressed("up") then
        self.scroll = math.max(1, self.scroll - 1)
      elseif input:wasPressed("a") then
        if deleteActiveSave(game) then
          if game.returnToTitle then game:returnToTitle() end
        else
          self.error = "SAVE DELETE FAILED"
        end
      end
    end

    local function fit(text)
      text = tostring(text or "")
      while #text > 0 and mod.ui.Font.width(text) > 152 do
        text = text:sub(1, -2)
      end
      return text
    end

    local function centered(text, y)
      text = fit(text)
      mod.ui.Font.draw(text,
        math.floor((160 - mod.ui.Font.width(text)) / 2), y)
    end

    function screen:draw()
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, 160, 144)
      love.graphics.setColor(0, 0, 0, 1)
      centered("NUZLOCKE FAILED", 4)
      centered(("%s  %d/%d"):format(self.pages[self.page].name,
        self.page, #self.pages), 20)

      if self.page == 1 then
        for index, text in ipairs(self.summary) do
          centered(text, 34 + (index - 1) * 13)
        end
      else
        local entries = self.pages[self.page].entries
        if #entries == 0 then
          centered("NO RECORDS", 62)
        else
          for row = 0, 2 do
            local entry = entries[self.scroll + row]
            if not entry then break end
            centered(entry.top, 34 + row * 24)
            centered(entry.bottom, 44 + row * 24)
          end
        end
      end

      centered("D-PAD: BROWSE", 108)
      local action = "RESTART GAME"
      local rowWidth = 8 + mod.ui.Font.width(action)
      local x = math.floor((160 - rowWidth) / 2)
      mod.ui.Font.drawCode(mod.ui.Theme.cursor, x, 124)
      mod.ui.Font.draw(action, x + 8, 124)
      if self.error then centered(self.error, 96) end
    end

    return screen
  end

  mod.exports.runReport = { newFailedScreen = newFailedScreen }

  mod.events:on("pokemon.caught", function(ev)
    if not active() then return end
    local game = ev and ev.game or mod.game
    local mon = ev and ev.mon
    append("run_catches", {
      species = ev and ev.species or mon and mon.species,
      name = mon and (mon.nickname or mon.species) or ev and ev.species,
      location = location(game),
    })
  end)

  mod.events:on("battle.fainted", function(ev)
    if not active() or setting(mod, "permadeath", true) ~= true then return end
    local battle = ev and ev.battle
    local battler = ev and (ev.mon or ev.battler)
    local mon = battler and battler.mon or battler
    local game = mod.game
    local party = game and game.save and game.save.party
    if not (battle and mon and party) or recordedDeaths[mon] then return end

    local owned = false
    for _, member in ipairs(party) do
      if member == mon then owned = true break end
    end
    if not owned then return end

    recordDeath(game, mon)
  end)

  local World = require("src.world.gen2.World")
  local poisonFaintScript = World.poisonFaintScript
  assert(type(poisonFaintScript) == "function",
    "Gold World.poisonFaintScript is unavailable; update this mod")
  World.poisonFaintScript = function(world, event, ...)
    if active() and setting(mod, "permadeath", true) == true then
      local game = world and world.game or mod.game
      local party = game and game.save and game.save.party or {}
      for _, index in ipairs(event and event.fainted or {}) do
        recordDeath(game, party[index])
      end
    end
    return poisonFaintScript(world, event, ...)
  end
end

return RunReport
