-- Gold-only randomizer and Nuzlocke for gen1recomp++.
-- Gameplay features are added independently and must ship with regression tests.
return function(mod)
  require("features.strict_encounters").install(mod)

  mod.exports.project = {
    generation = 2,
    game = "gold",
    status = "strict-first-encounters",
  }
end
