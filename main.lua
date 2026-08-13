-- Gold-only randomizer and Nuzlocke for gen1recomp++.
-- Gameplay features are added independently and must ship with regression tests.
return function(mod)
  local path = "features/strict_encounters.lua"
  local source = mod:read(path)
  assert(source, path .. " is missing; reinstall the mod")
  local chunk, compileError = load(source, "@" .. mod.path .. "/" .. path)
  assert(chunk, compileError)
  local feature = chunk()
  assert(type(feature) == "table" and type(feature.install) == "function",
    path .. " must return a feature installer")
  feature.install(mod)

  mod.exports.project = {
    generation = 2,
    game = "gold",
    status = "strict-first-encounters",
  }
end
