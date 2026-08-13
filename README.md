<div align="center">

# Gen1Recomp++ Randomizer Nuzlocke

### A configurable, strictly enforced Pokémon Gold Nuzlocke for gen1recomp++

![Pokémon Gold](https://img.shields.io/badge/game-Pok%C3%A9mon%20Gold-d4af37?style=flat-square)
![Version](https://img.shields.io/badge/version-0.13.0-4c8bf5?style=flat-square)
![Mod API](https://img.shields.io/badge/mod%20API-2-6f42c1?style=flat-square)
![Status](https://img.shields.io/badge/status-active-success?style=flat-square)

</div>

Turn Pokémon Gold into a configurable Nuzlocke where the rules are enforced by
the game instead of being left to an honour system. Encounters are tracked by
location, fainted Pokémon are permanently removed, levels are capped and
scaled, and a failed run ends with a complete run report.

> [!IMPORTANT]
> This mod is **Pokémon Gold only** and targets the Gen 2 support in
> [gen1recomp++](https://github.com/bryanthaboi/gen1recomp). It does not support
> Pokémon Red, Blue, or Yellow.

> [!NOTE]
> The Nuzlocke and level-scaling foundation is implemented now. Pokémon, item,
> trainer, and encounter randomization are planned features and are **not yet
> included** in the current release.

## Contents

- [Highlights](#highlights)
- [Installation](#installation)
- [Configuring a run](#configuring-a-run)
- [Encounter rules](#encounter-rules)
- [Permadeath and failed runs](#permadeath-and-failed-runs)
- [Level caps](#level-caps)
- [Level scaling](#level-scaling)
- [Additional challenge rules](#additional-challenge-rules)
- [Compatibility](#compatibility)
- [Development](#development)

## Highlights

| Feature | What it does |
| --- | --- |
| Strict encounters | Enforces one eligible encounter per named area and permanently records catches and failures. |
| Evolution-family dupes | Skips, loses, or allows duplicate evolutionary lines according to your chosen policy. |
| Shiny clause | Lets shinies bypass route and duplicate restrictions without changing the area's normal encounter. |
| Permadeath | Removes fainted party Pokémon and refuses Revives. |
| Reserve recovery | After a wipe, automatically recovers one Pokémon from the PC or Day Care before ending the run. |
| Mandatory nicknames | Requires a real custom nickname for catches, starters, gifts, and hatched Eggs. |
| Level caps | Stops EXP, Rare Candies, and Day-Care growth at the next major challenge. |
| Dynamic scaling | Keeps underlevelled wild Pokémon, trainers, and Kanto leaders relevant to the current party. |
| Static and gift policies | Controls whether special encounters consume an area, count as a bonus, or are forbidden. |
| Set mode | Can permanently enforce `SET` battle style. |
| No battle items | Can forbid every manually used battle item except Poké Balls. |
| Run reports | Records catches, encounter failures, deaths, badges, and play time for the failed-run screen. |

## Installation

### Requirements

- A current gen1recomp++ build with Pokémon Gold support.
- A legally obtained Pokémon Gold ROM supplied to gen1recomp++.
- The packaged mod `.zip`.

The mod contains no ROM, game assets, or ROM-derived content.

### Install the mod

1. Open the gen1recomp++ launcher.
2. Open the **Mods** tab.
3. Choose **Import mod .zip**, or drag the mod archive onto the launcher.
4. Enable **Gen1Recomp++ Randomizer Nuzlocke**.
5. Launch Pokémon Gold and begin a new game.

Professor Oak presents the complete ruleset during the new-game introduction.
Settings can also be reviewed or changed later from:

```text
START → NUZLOCKE
```

## Configuring a run

Every configurable feature is available both during Oak's introduction and in
the in-game Nuzlocke settings screen.

| Setting | Default | Options | Behaviour |
| --- | :---: | --- | --- |
| `1ST ENCOUNTER` | `ON` | `ON` / `OFF` | Enforces one encounter per named area. |
| `DUPES` | `SKIP` | `SKIP` / `LOSE` / `OFF` | Chooses how previously caught evolution families affect a new area. |
| `SHINY CLAUSE` | `ON` | `ON` / `OFF` | Allows shiny Pokémon to bypass encounter limits. |
| `PERMADEATH` | `ON` | `ON` / `OFF` | Permanently removes Pokémon that faint. |
| `MANDATORY NAMES` | `ON` | `ON` / `OFF` | Requires every obtained Pokémon to have a custom nickname. |
| `LEVEL CAPS` | `ON` | `ON` / `OFF` | Prevents the party from levelling beyond the active challenge cap. |
| `LEVEL SCALING` | `ON` | `ON` / `OFF` | Scales weaker wild Pokémon, trainers, and Kanto leaders. |
| `SET MODE` | `ON` | `ON` / `OFF` | Locks Battle Style to `SET`. |
| `NO BATTLE ITEMS` | `OFF` | `OFF` / `ON` | Forbids non-Ball items during battle. |
| `STATIC` | `AREA` | `AREA` / `BONUS` / `FORBID` | Controls scripted static encounters. |
| `GIFTS` | `BONUS` | `BONUS` / `AREA` | Controls gifted Pokémon and Eggs. |

## Encounter rules

### When the Nuzlocke begins

The run begins permanently when the player first owns **any item from the Ball
pocket**. Encounters seen before that moment never consume or fail an area.
This is a hard rule and cannot be disabled.

Trainer battles, the catching tutorial, and the Bug-Catching Contest do not
consume normal area encounters. Gold maps that share the same named landmark
also share one encounter allocation.

### First encounters

The first eligible wild encounter reserves its named area immediately.

| Encounter outcome | Area result |
| --- | --- |
| Pokémon caught | Area is permanently marked as caught. |
| Pokémon knocked out | Area is permanently failed. |
| Player runs | Area is permanently failed. |
| Wild Pokémon flees | Area is permanently failed. |
| Player loses the battle | Area is permanently failed. |
| Ball misses during the active encounter | The encounter remains active; no second allocation is consumed. |

Once an area is used, the game refuses further Poké Balls **before** spending
the Ball or the player's turn. The refusal identifies the Pokémon and whether
the area was caught or failed.

### Dupes clause

Duplicate detection covers the entire evolutionary family. Catching a Pidgey,
for example, also treats Pidgeotto and Pidgeot as duplicates.

| Policy | Result when the encounter is a duplicate |
| --- | --- |
| `SKIP` | The encounter is ignored and the area remains available for a new species. |
| `LOSE` | The encounter immediately fails the area. |
| `OFF` | The duplicate becomes the area's normal encounter. |

### Shiny clause

With `SHINY CLAUSE` enabled, a shiny Pokémon bypasses caught areas, failed
areas, and every dupes policy. Catching, defeating, or leaving the shiny never
consumes, repairs, or replaces the area's ordinary encounter record.

The static encounter policy takes priority over the shiny clause. A forbidden
static encounter remains forbidden even when shiny.

### Static encounters

This policy applies to scripted encounters such as Sudowoodo, the Red
Gyarados, Snorlax, and legendary Pokémon. Detection follows the encounter's
scripted origin rather than a species list, so future randomization will not
break the rule.

| Policy | Behaviour |
| --- | --- |
| `AREA` | Uses the surrounding area's encounter allocation. |
| `BONUS` | Can be caught separately and leaves the area's normal allocation unchanged. |
| `FORBID` | Cannot be caught. |

### Gifts and Eggs

Gift policy covers starters, Eevee, Shuckie, Togepi's Egg, Game Corner
Pokémon, and other scripted gifts.

| Policy | Behaviour |
| --- | --- |
| `BONUS` | The gift is separate from normal encounters. |
| `AREA` | The gift consumes the landmark where it is received and is refused when that landmark is already used. |

Blocked gifts remain retryable: event flags, coins, and other resources are not
consumed. Failed or full-party grants do not reserve the area. Eggs count where
they are received, not where they hatch. In-game and link trades are excluded.

## Permadeath and failed runs

When `PERMADEATH` is enabled, a party Pokémon that faints after the run begins
is removed when the battle finishes. The same rule applies to overworld poison
faints. Revives are refused without being consumed.

### Party wipe recovery

The mod checks every owned reserve before ending the run:

1. Remove every fainted party member.
2. Withdraw the first living, non-Egg Pokémon in PC box order.
3. If no boxed backup exists, withdraw the first deposited Day-Care Pokémon.
4. If no usable reserve exists, end the run and delete its active save file.

Emergency Day-Care withdrawal is free and applies the Pokémon's accrued
experience and moves normally. A waiting Day-Care Egg by itself cannot rescue
the run.

### Failed-run report

A terminal wipe opens a non-dismissible `NUZLOCKE FAILED` screen. Its only
action is `RESTART GAME`; B cannot return to the deleted save.

| Page | Recorded information |
| --- | --- |
| `SUMMARY` | Johto and Kanto badges, play time, catches, failed encounters, and known deaths. |
| `ENCOUNTERS` | Successful catches and strict encounter failures, including landmark and failure reason. |
| `MEMORIAL` | Every lost Pokémon's nickname, level, and death location. |

Use Left/Right to change pages and Up/Down to scroll longer histories. Upgraded
runs clearly mark history from before journalling support as unrecorded.

## Level caps

With `LEVEL CAPS` enabled, battle EXP, Rare Candies, and Day-Care growth stop
at the current major-challenge cap. Beating the relevant challenge immediately
unlocks the next cap. The active value is always visible in the Nuzlocke
settings screen.

### Johto

| Next challenge | Level cap | Next challenge | Level cap |
| --- | :---: | --- | :---: |
| Falkner | 9 | Chuck | 30 |
| Bugsy | 16 | Pryce | 31 |
| Whitney | 20 | Jasmine | 35 |
| Morty | 25 | Clair | 40 |
| Elite Four / Champion | 50 |  |  |

Pryce is checked before Jasmine so completing those Gyms out of their listed
badge order can never reduce an already unlocked cap.

### Kanto and Red

With level scaling disabled, Kanto keeps a level 50 cap until seven Kanto
badges, rises to 58 for Blue, and then rises to 81 for Red.

With level scaling enabled, Kanto progresses by badge count:

| Kanto badges | Next leader's ace / player cap |
| :---: | :---: |
| 0 | 52 |
| 1 | 55 |
| 2 | 58 |
| 3 | 61 |
| 4 | 64 |
| 5 | 67 |
| 6 | 70 |
| 7 (Blue) | 75 |
| 8 (Red) | 81 |

Defeating Red removes the level cap entirely.

## Level scaling

Scaling is based only on the highest-level non-Egg Pokémon currently in the
party. Boxed and Day-Care Pokémon are ignored.

For ordinary wild Pokémon and trainers, the target is:

```text
floor(highest party level × 80%) + random variance from -2 to +2
```

The final level is never lower than the vanilla level and never higher than
the active level cap. This means appropriately levelled opponents remain
unchanged while badly underlevelled opponents catch up.

- Scaled Pokémon regenerate the latest four natural level-up moves available
  at their new level.
- Explicitly authored trainer movesets are preserved.
- Repels evaluate the Pokémon's final scaled level, not its old vanilla level.
- Kanto leaders keep their original team-wide level spread while their ace is
  raised to the current Kanto target.
- Blue targets level 75 and Red targets level 81.

## Additional challenge rules

### Mandatory nicknames

Every wild catch, starter, scripted gift, hatched Egg, and Bug-Catching Contest
reward must receive a nonblank nickname different from its species name. Blank
or default names show an explanation and keep the naming screen open.
Pre-nicknamed in-game trades already satisfy the rule.

### Set mode

When enabled, Gold's Battle Style is forced to `SET`. The Options screen cannot
select `SHIFT`, and defeating an opponent never offers a free switch before
their replacement enters battle. Disabling the rule restores normal control
without changing the current selection.

### No battle items

When enabled, manually selected battle items are refused before consuming the
item or the player's turn.

- Poké Balls remain usable.
- Held-item effects still work normally.
- Items remain usable outside battle.

## Compatibility

| Item | Support |
| --- | --- |
| Pokémon Gold | Supported |
| Pokémon Silver / Crystal | Not currently supported |
| Pokémon Red / Blue / Yellow | Not supported |
| gen1recomp++ Mod API | API 2 |
| Current mod version | 0.13.0 |

Gold v0.1.80 predates several public enforcement hooks used by this project.
The mod therefore declares the `engine_internals` permission and directly
supports the required Gold nickname, Ball-use, battle-finish, and poison-faint
paths.

## Project principles

- Build and validate one gameplay feature at a time.
- Enforce rules in code instead of relying on the player.
- Preserve vanilla behaviour unless an enabled rule requires a change.
- Keep the implementation Gold-specific, direct, and maintainable.
- Add regression coverage for every rule and discovered edge case.

## Development

Run validation from the gen1recomp++ repository root with this repository next
to it:

```sh
for test_file in ../gen1recomp-plus-randomizer-nuzlocke/tests/*_test.lua; do
  luajit "$test_file"
done

python3 tools/modkit.py validate \
  ../gen1recomp-plus-randomizer-nuzlocke --base fixture
python3 tools/modkit.py gen2check \
  ../gen1recomp-plus-randomizer-nuzlocke --strict
python3 tools/modkit.py lint ../gen1recomp-plus-randomizer-nuzlocke
```

## License

Released under the [MIT License](LICENSE).
