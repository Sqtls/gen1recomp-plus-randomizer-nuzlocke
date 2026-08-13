return function(game)
  local MOD_ID = "gen1recomp_plus_randomizer_nuzlocke"
  local world = game.world

  local function wait(frames)
    for _ = 1, frames do coroutine.yield() end
  end

  local function tap(button)
    table.insert(game.input.pressQueue, button)
    coroutine.yield()
    game.input.state[button] = false
  end

  wait(45)
  local bucket = assert(game.mods and game.mods.modSave
    and game.mods.modSave[MOD_ID], "Nuzlocke mod save is unavailable")
  bucket.starter_randomizer = "chaos"
  bucket.starter_legendaries = "allow"
  bucket.randomizer_seed = 1859415114

  world.mapScenes.ELMS_LAB = 1
  world:setMap("ELMS_LAB", 6, 4, "up")
  wait(20)

  local shown
  local realShow = world.showPokePic
  world.showPokePic = function(self, species)
    shown = species
    return realShow(self, species)
  end

  for _ = 1, 80 do
    tap("a")
    if shown then break end
    wait(3)
  end

  assert(shown ~= nil, "Elm starter script did not show a Pokemon")
  assert(shown ~= 155,
    "starter randomizer left the Cyndaquil ball as species 155")
  print("[driver] PASS randomized Elm starter species: " .. tostring(shown))
  love.event.quit()
end
