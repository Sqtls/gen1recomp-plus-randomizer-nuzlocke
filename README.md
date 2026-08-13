# Gen1Recomp Plus Randomizer Nuzlocke

An all-in-one Pokémon Gold randomizer and Nuzlocke mod for the Gen 2 support
in gen1recomp++, built one independently validated feature at a time.

## Status

Strict first encounters, the dupes and shiny clauses, party permadeath,
failed-run reports, mandatory nicknames, level caps, level scaling, enforced
Set battle mode, and the optional no-battle-items challenge are implemented.

- Oak configures `1ST ENCOUNTER`, the `SKIP`/`LOSE` duplicate-family rule, and
  the shiny clause for each new run.
- `START` → `NUZLOCKE` changes those settings for the active save.
- The first eligible wild encounter reserves the whole named area. Catching it
  seals the area as caught; knocking it out, running, losing, or letting it flee
  permanently fails the area.
- Failed ball throws do not consume another encounter while the same battle is
  still active.
- Trainer battles, the catching tutorial, and the Bug-Catching Contest are
  exempt.
- Gold maps sharing the same landmark share one encounter allocation.
- The Nuzlocke starts permanently when the player first owns any item from the
  Ball pocket; wild encounters before that moment never consume an area.
- Blocked balls show the recorded encounter outcome and return before the ball
  or turn is consumed, including on Gold v0.1.80.
- With `SHINY CLAUSE` enabled, a shiny bypasses used and failed route limits as
  well as both dupes modes. Catching or leaving it never consumes, repairs, or
  replaces the area's normal encounter record.
- With `MANDATORY NAMES` enabled, every wild catch, starter, scripted gift,
  hatched Egg, and Bug-Catching Contest reward must receive a nonblank nickname
  different from its species name. Pre-nicknamed in-game trades already satisfy
  the rule. Oak and `START` → `NUZLOCKE` both expose the setting, which defaults
  to ON. Rejected blank and species-default entries show an inline explanation
  and keep the naming screen open.
- With `LEVEL CAPS` enabled, battle EXP, Rare Candies, and Day Care growth stop
  at the current major-challenge cap. The settings screen displays that cap.
  Progressing past a milestone immediately permits growth to the next cap.
- Johto caps are Falkner 9, Bugsy 16, Whitney 20, Morty 25, Chuck 30, Pryce
  31, Jasmine 35, and Clair 40. Pryce is deliberately checked before Jasmine
  so the cap never falls from 35 back to 31 when those gyms are done out of
  order.
- The Elite Four and Champion cap is 50. With `LEVEL SCALING` off, Kanto stays
  at 50 until seven Kanto badges, rises to 58 for Blue, then 81 for Red.
- With `LEVEL SCALING` enabled, wild Pokémon and ordinary trainer roster
  members scale around 80% of the highest-level non-Egg Pokémon currently in
  the party, with a random variance of two levels in either direction. Vanilla
  levels are never reduced and scaling never raises an addition past the active
  cap. Scaled Pokémon regenerate the latest four natural moves available at
  their new level; explicitly authored trainer movesets remain unchanged.
  Boxed Pokémon are ignored, and Repels evaluate the final scaled wild level.
- Kanto leaders use ace targets of 52, 55, 58, 61, 64, 67, and 70 based on the
  number of Kanto badges already owned, so they remain open-order. Each roster
  keeps its original level spread. Blue's target is 75 and Red's is 81; player
  caps advance to the same targets. Defeating Red removes the cap.
- With `SET MODE` enabled, Gold's Battle Style is forced to `SET`, the OPTION
  screen cannot select `SHIFT`, and defeating an opposing Pokémon never offers
  a free switch before the replacement appears. Disabling the rule restores
  normal `SHIFT`/`SET` control without changing the current selection.
- With `NO BATTLE ITEMS` enabled, manually selected items are refused before
  consumption or turn use. Poké Balls remain usable, held-item effects still
  trigger normally, and item use outside battle is unchanged. This optional
  challenge defaults to OFF and is configurable through Oak and `NUZLOCKE`.

Gold v0.1.80 is handled directly for starter/scripted-gift and wild-catch
nickname flows because that build predates the public nickname hook call sites.

Gold v0.1.80 lacks public hooks at several required enforcement boundaries, so
this version uses `engine_internals` for Gold's ball use, battle finish, and
overworld poison-faint paths.

When `PERMADEATH` is enabled, a party Pokémon that faints after the run starts
is removed when its battle finishes. Revives are refused without being spent.
If the whole party dies, the first living non-Egg Pokémon in PC box order is
withdrawn before the blackout respawn; fainted boxed Pokémon and Eggs are
skipped. If no eligible backup exists, the run ends on a non-dismissible
centered `NUZLOCKE FAILED` screen after the blackout respawn and the failed
run's active save file is deleted. Its only action restarts at the title
screen. Empty-party saves produced by v0.3.0 are repaired into the same
rescue-or-game-over state when loaded. Overworld poison faints follow the same
rule.

The failed-run screen has three pages navigated with Left/Right:

- `SUMMARY` shows all Johto/Kanto badges, play time, catches, failed
  encounters, and known deaths.
- `ENCOUNTERS` lists successful catches and strict encounter failures with
  their Gold landmark and failure reason.
- `MEMORIAL` lists each lost Pokémon's nickname, level, and death location.

Up/Down scrolls longer histories. `RESTART GAME` remains the only action and B
cannot dismiss the report. New runs keep a complete journal in the save;
upgraded active runs clearly mark history from before v0.4.0 as unrecorded.

## Principles

- Gold only; no Gen 1 compatibility layer.
- Each gameplay feature is implemented and validated independently.
- Rules are strictly enforced by the mod rather than relying on the player.
- Existing behavior stays unchanged unless an enabled feature requires it.

## Development

From the gen1recomp++ repository root:

```sh
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/strict_encounters_test.lua
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/permadeath_test.lua
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/run_report_test.lua
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/mandatory_nicknames_test.lua
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/level_caps_test.lua
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/level_scaling_test.lua
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/forced_set_mode_test.lua
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/no_battle_items_test.lua
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/smoke_test.lua
luajit ../gen1recomp-plus-randomizer-nuzlocke/tests/loader_integration_test.lua
python3 tools/modkit.py validate ../gen1recomp-plus-randomizer-nuzlocke --base fixture
python3 tools/modkit.py gen2check ../gen1recomp-plus-randomizer-nuzlocke --strict
python3 tools/modkit.py lint ../gen1recomp-plus-randomizer-nuzlocke
```
