# Gen1Recomp Plus Randomizer Nuzlocke

An all-in-one Pokémon Gold randomizer and Nuzlocke mod for the Gen 2 support
in gen1recomp++, built one independently validated feature at a time.

## Status

Foundation only. This version intentionally changes no gameplay.

## Principles

- Gold only; no Gen 1 compatibility layer.
- Each gameplay feature is implemented and validated independently.
- Rules are strictly enforced by the mod rather than relying on the player.
- Existing behavior stays unchanged unless an enabled feature requires it.

## Development

From the gen1recomp++ repository root:

```sh
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/smoke_test.lua
python3 tools/modkit.py validate ../gen1recomp-plus-randomizer-nuzlocke --base fixture
python3 tools/modkit.py gen2check ../gen1recomp-plus-randomizer-nuzlocke --strict
python3 tools/modkit.py lint ../gen1recomp-plus-randomizer-nuzlocke
```
