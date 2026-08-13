local OwnershipHistory = {}

local function speciesOf(value)
  if type(value) == "table" then return value.species end
  return value
end

function OwnershipHistory.install(mod)
  local function history()
    local owned = mod.save:get("ever_owned")
    if type(owned) ~= "table" then
      owned = {}
      mod.save:set("ever_owned", owned)
    end
    return owned
  end

  local function record(value)
    local species = speciesOf(value)
    if species == nil then return false end
    local owned = history()
    if owned[species] == true then return false end
    owned[species] = true
    mod.save:set("ever_owned", owned)
    return true
  end

  local function recordMons(mons)
    for _, mon in pairs(type(mons) == "table" and mons or {}) do
      record(mon)
    end
  end

  local function sync(game)
    local save = game and game.save or {}
    local pokedex = save.pokedex or {}
    for species, caught in pairs(pokedex.caught or {}) do
      if caught then record(species) end
    end
    for species, owned in pairs(pokedex.owned or {}) do
      if owned then record(species) end
    end
    recordMons(save.party)
    for _, box in pairs(save.boxes or {}) do recordMons(box) end
    local dayCare = save.dayCare or {}
    record(dayCare.man and dayCare.man.mon)
    record(dayCare.lady and dayCare.lady.mon)
    for _, area in pairs(mod.save:get("encounter_areas") or {}) do
      if type(area) == "table" and area.status == "caught" then
        record(area.species)
      end
    end
    return history()
  end

  local function ownsFamily(game, members)
    local owned = sync(game)
    for species in pairs(members or {}) do
      if owned[species] == true then return true end
    end
    return false
  end

  for _, event in ipairs({
    "pokemon.caught", "pokemon.received", "egg.hatched",
  }) do
    mod.events:on(event, function(ev)
      record(ev and (ev.species or ev.mon))
    end)
  end
  mod.events:on("pokemon.evolved", function(ev)
    record(ev and ev.fromSpecies)
    record(ev and (ev.toSpecies or ev.mon))
  end)
  mod.events:on("save.loaded", function() sync(mod.game) end)
  mod.events:on("save.created", function() sync(mod.game) end)

  mod.exports.ownershipHistory = {
    record = record,
    sync = sync,
    ownsFamily = ownsFamily,
  }
end

return OwnershipHistory
