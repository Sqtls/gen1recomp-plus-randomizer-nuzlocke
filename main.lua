-- Gold-only randomizer and Nuzlocke for gen1recomp++.
-- Gameplay features are added independently and must ship with regression tests.
return function(mod)
  local function install(path)
    local source = mod:read(path)
    assert(source, path .. " is missing; reinstall the mod")
    local chunk, compileError = load(source, "@" .. mod.path .. "/" .. path)
    assert(chunk, compileError)
    local feature = chunk()
    assert(type(feature) == "table" and type(feature.install) == "function",
      path .. " must return a feature installer")
    feature.install(mod)
  end

  install("features/ownership_history.lua")
  install("features/strict_encounters.lua")
  install("features/run_report.lua")
  install("features/permadeath.lua")
  install("features/run_completion.lua")
  install("features/mandatory_nicknames.lua")
  install("features/gift_encounters.lua")
  install("features/breeding_eggs.lua")
  install("features/wild_randomizer.lua")
  install("features/static_randomizer.lua")
  install("features/starter_randomizer.lua")
  install("features/level_caps.lua")
  install("features/level_scaling.lua")
  install("features/forced_set_mode.lua")
  install("features/no_battle_items.lua")

  mod.exports.project = {
    generation = 2,
    game = "gold",
    status = "wild-static-and-starter-randomizers-successful-ending-locked-rules-strict-encounters-permanent-dupes-shiny-static-gift-roaming-and-breeding-policies-permadeath-run-reports-mandatory-nicknames-level-caps-level-scaling-forced-set-mode-and-no-battle-items",
  }
end
