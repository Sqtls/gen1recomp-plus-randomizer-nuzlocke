# Gen1Recomp Plus Randomizer Nuzlocke

An all-in-one Pokémon Gold randomizer and Nuzlocke mod for the Gen 2 support
in gen1recomp++, built one independently validated feature at a time.

## Status

The first feature is strict first-encounter enforcement.

- Oak configures `1ST ENCOUNTER` and the `SKIP`/`LOSE` duplicate-family rule
  for each new run.
- `START` → `NUZLOCKE` changes those settings for the active save.
- The first eligible wild encounter reserves the whole named area. Catching it
  seals the area as caught; knocking it out, running, losing, or letting it flee
  permanently fails the area.
- Failed ball throws do not consume another encounter while the same battle is
  still active.
- Trainer battles, the catching tutorial, and the Bug-Catching Contest are
  exempt.
- Gold maps sharing the same landmark share one encounter allocation.
- Blocked balls show the recorded encounter outcome and return before the ball
  or turn is consumed, including on Gold v0.1.80.

Gold v0.1.80 lacks a public hook before ball consumption, so this version uses
the `engine_internals` permission solely to gate that Gold item-use boundary.

## Principles

- Gold only; no Gen 1 compatibility layer.
- Each gameplay feature is implemented and validated independently.
- Rules are strictly enforced by the mod rather than relying on the player.
- Existing behavior stays unchanged unless an enabled feature requires it.

## Development

From the gen1recomp++ repository root:

```sh
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/strict_encounters_test.lua
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/smoke_test.lua
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/loader_integration_test.lua
python3 tools/modkit.py validate ../gen1recomp-plus-randomizer-nuzlocke --base fixture
python3 tools/modkit.py gen2check ../gen1recomp-plus-randomizer-nuzlocke --strict
python3 tools/modkit.py lint ../gen1recomp-plus-randomizer-nuzlocke
```
