<div align="center">

# Gen1Recomp++ Randomizer Nuzlocke

### A configurable, strictly enforced Pokémon Gold Nuzlocke for gen1recomp++

![Pokémon Gold](https://img.shields.io/badge/game-Pok%C3%A9mon%20Gold-d4af37?style=flat-square)
![Version](https://img.shields.io/badge/version-0.27.0-4c8bf5?style=flat-square)
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
> Wild, static, starter, gift, and trainer Pokémon randomization are implemented
> now. Roaming, item, move, ability, and evolution randomizers are planned
> as focused follow-up features and are **not yet included** in the current
> release.

## Contents

- [Highlights](#highlights)
- [Installation](#installation)
- [Configuring a run](#configuring-a-run)
- [Wild randomization](#wild-randomization)
- [Static randomization](#static-randomization)
- [Starter randomization](#starter-randomization)
- [Gift randomization](#gift-randomization)
- [Trainer randomization](#trainer-randomization)
- [Item randomization](#item-randomization)
- [Encounter rules](#encounter-rules)
- [Permadeath and run endings](#permadeath-and-run-endings)
- [Level caps](#level-caps)
- [Level scaling](#level-scaling)
- [Additional challenge rules](#additional-challenge-rules)
- [Compatibility](#compatibility)
- [Development](#development)

## Highlights

| Feature | What it does |
| --- | --- |
| Locked ruleset | Permanently locks every configured rule when the player first obtains a Ball. |
| Seeded wild randomizer | Replaces ordinary wild species using balanced or unrestricted slot mappings that remain stable for the full run. |
| Static randomizer | Replaces scripted static battles while optionally guaranteeing legendary-to-legendary mapping. |
| Starter randomizer | Generates three unique starter choices and keeps the rival's starter line synchronized. |
| Gift randomizer | Replaces scripted gifts, Togepi's Egg, Game Corner Pokémon, and Shuckie while preserving their event behavior. |
| Trainer randomizer | Replaces trainer parties deterministically while preserving party size, final levels, items, and rival starter continuity. |
| Item randomizer | Replaces found, hidden, gifted, berry-tree, and Gym Leader TM items while leaving key items and HMs untouched. |
| Strict encounters | Enforces one eligible encounter per named area and permanently records catches and failures. |
| Evolution-family dupes | Skips, loses, or allows duplicate evolutionary lines according to your chosen policy, using every species ever owned during the run. |
| Shiny clause | Lets shinies bypass route and duplicate restrictions without changing the area's normal encounter. |
| Roaming encounters | Tracks each roaming slot across routes until that Pokémon is caught or defeated. |
| Permadeath | Removes fainted party Pokémon and refuses Revives. |
| Reserve recovery | After a wipe, automatically recovers one Pokémon from the PC or Day Care before ending the run. |
| Mandatory nicknames | Requires a real custom nickname for catches, starters, gifts, and hatched Eggs. |
| Level caps | Stops EXP, Rare Candies, and Day-Care growth at the next major challenge. |
| Dynamic scaling | Keeps underlevelled wild Pokémon, trainers, and Kanto leaders relevant to the current party. |
| Static and gift policies | Controls whether special encounters consume an area, count as a bonus, or are forbidden. |
| Breeding Egg policy | Forbids bred Eggs, limits them to the Day-Care area, or preserves unrestricted breeding. |
| Set mode | Can permanently enforce `SET` battle style. |
| No battle items | Can forbid every manually used battle item except Poké Balls. |
| Run reports | Records catches, encounter failures, deaths, badges, and play time for the failed-run screen. |
| Successful ending | Marks the run complete after defeating Red and presents the final party and full run report. |

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

The new game plays out exactly as Gold ships it. The Nuzlocke settings screen
opens by itself the first time the player spawns in their bedroom, and can be
reopened later from:

```text
START → NUZLOCKE
```

## Configuring a run

Every configurable feature is set from the Nuzlocke settings screen, which
opens automatically on the first spawn at home and stays editable from the
START menu until the run starts. Pressing SELECT on any row explains what that
rule does and what each of its values means. Obtaining any Ball permanently
locks the ruleset for that save. The screen remains available as a read-only
summary of the active rules and current level cap.

| Setting | Default | Options | Behaviour |
| --- | :---: | --- | --- |
| `1ST ENCOUNTER` | `ON` | `ON` / `OFF` | Enforces one encounter per named area. |
| `DUPES` | `SKIP` | `SKIP` / `LOSE` / `OFF` | Chooses how previously caught evolution families affect a new area. |
| `SHINY CLAUSE` | `ON` | `ON` / `OFF` | Allows shiny Pokémon to bypass encounter limits. |
| `PERMADEATH` | `ON` | `ON` / `OFF` | Permanently removes Pokémon that faint. |
| `NICKNAMES` | `ON` | `ON` / `OFF` | Requires every obtained Pokémon to have a custom nickname. |
| `LEVEL CAPS` | `ON` | `ON` / `OFF` | Prevents the party from levelling beyond the active challenge cap. |
| `LEVEL SCALING` | `ON` | `ON` / `OFF` | Scales weaker wild Pokémon, trainers, and Kanto leaders. |
| `WILD LVL` | `-20%` | `-0%` … `-50%` | How far below the party maximum wild Pokémon are scaled. |
| `TRAINER LVL` | `-20%` | `-0%` … `-50%` | How far below the party maximum ordinary trainers are scaled. |
| `SET MODE` | `ON` | `ON` / `OFF` | Locks Battle Style to `SET`. |
| `NO ITEMS` | `OFF` | `OFF` / `ON` | Forbids non-Ball items during battle. |
| `STATIC` | `AREA` | `AREA` / `BONUS` / `FORBID` | Controls scripted static encounters. |
| `GIFTS` | `BONUS` | `BONUS` / `AREA` | Controls gifted Pokémon and Eggs. |
| `BREEDING` | `FORBID` | `FORBID` / `AREA` / `BONUS` | Controls Eggs produced by the Day Care. |
| `WILDS` | `OFF` | `OFF` / `BALANCED` / `CHAOS` | Controls ordinary wild species randomization. |
| `WILD LEG` | `EXCLUDE` | `EXCLUDE` / `ALLOW` | Controls whether ordinary wild slots may become legendary Pokémon. |
| `STATICS` | `OFF` | `OFF` / `BALANCED` / `CHAOS` | Controls scripted static species randomization. |
| `STATIC LEG` | `MATCH` | `MATCH` / `ANY` | Controls whether legendary status must match the original static encounter. |
| `STARTERS` | `OFF` | `OFF` / `BALANCED` / `CHAOS` | Controls the three starter species. |
| `START LEG` | `EXCLUDE` | `EXCLUDE` / `ALLOW` | Controls whether a starter may be legendary or mythical. |
| `GIFT MON` | `OFF` | `OFF` / `BALANCED` / `CHAOS` | Controls gifted Pokémon and scripted Egg species randomization. |
| `GIFT LEG` | `EXCLUDE` | `EXCLUDE` / `ALLOW` | Controls whether non-Egg gifts may become legendary or mythical. |
| `TRAINERS` | `OFF` | `OFF` / `BALANCED` / `CHAOS` | Controls trainer party species randomization. |
| `TRAIN LEG` | `EXCLUDE` | `EXCLUDE` / `ALLOW` | Controls whether trainer slots may become legendary or mythical. |
| `BOSSES` | `INCLUDE` | `INCLUDE` / `EXCLUDE` | Controls whether major boss teams are randomized. |
| `ITEMS` | `OFF` | `OFF` / `BALANCED` / `CHAOS` | Controls found, hidden, gifted, berry-tree, and TM reward item randomization. |
| `SEED` | Generated | Read-only | Shows the stable seed used for this run's randomization. |

## Wild randomization

`WILDS` changes species while preserving the encounter's original
level. The existing level-scaling rule then evaluates and scales that final
Pokémon normally.

| Mode | Behaviour |
| --- | --- |
| `OFF` | Preserves Gold's original wild species. |
| `BALANCED` | Replaces each species with one at the same evolution stage and within 10 percent BST, with a minimum 25-point window. If no exact window match exists, it chooses from the closest same-stage species. |
| `CHAOS` | Replaces slots from the complete allowed Gen 1 and Gen 2 species pool without BST or evolution-stage limits. |

The mapping is deterministic for the run. The seed, map, encounter method,
time of day, and table slot ensure that revisiting the same encounter table
does not reroll it. The seed is generated when the save is created and remains
visible from `START → NUZLOCKE`.

The randomizer covers grass, caves, Surf, Sweet Scent, fishing, Headbutt trees,
Rock Smash, and ordinary swarm tables. All Headbutt trees that use the same
Gold encounter table share its randomized slots rather than becoming separate
locations.

`WILD LEG` is limited to ordinary wild tables:

- `EXCLUDE` prevents those slots from becoming legendary or mythical Pokémon.
- `ALLOW` includes legendary and mythical Pokémon in the available pool.

Bug-Catching Contest encounters, the catching tutorial, scripted static
encounters, roaming Pokémon, gifts, and trainer parties are deliberately
excluded from the wild randomizer. Native Unown slots stay as Unown so Gold's
puzzle and form-unlock logic cannot silently remove encounters.

## Static randomization

`STATICS` randomizes scripted battles such as Sudowoodo, the Red Gyarados,
Snorlax, Electrode, and stationary legendary Pokémon. It uses the same stable
run seed and matching rules as ordinary wild randomization.

| Mode | Behaviour |
| --- | --- |
| `OFF` | Preserves the scripted species. |
| `BALANCED` | Chooses the same evolution stage within the similar-BST window, falling back to the closest same-stage species. |
| `CHAOS` | Chooses from the complete permitted Gen 1 and Gen 2 species pool. |

`STATIC LEG` controls the permitted pool independently of the mode:

| Policy | Behaviour |
| --- | --- |
| `MATCH` | Legendary and mythical statics become another legendary or mythical species. Nonlegendary statics remain nonlegendary. |
| `ANY` | Removes the legendary-status restriction. In `CHAOS`, Lugia may become Pidgey and Sudowoodo may become Mewtwo. |

The battle keeps the scripted level before optional level scaling runs. Catch
rates, stats, typing, and natural moves come from the replacement species. The
Red Gyarados replacement remains forced shiny. Script text, map sprites, and
pre-battle cries remain original so event scripts and story progression stay
compatible.

Static randomization and the `STATIC` Nuzlocke policy are separate settings.
Randomization decides which Pokémon appears. `AREA`, `BONUS`, or `FORBID`
still decides whether it may be caught and whether it consumes the area.

## Starter randomization

`STARTERS` generates three deterministic, unique choices for Elm's Lab.
Revisiting a Ball or reloading the save cannot reroll the choices.

| Mode | Behaviour |
| --- | --- |
| `OFF` | Preserves Chikorita, Cyndaquil, and Totodile. |
| `BALANCED` | Replaces each original with a similar-BST base-stage Pokémon that can evolve. |
| `CHAOS` | Chooses from the complete permitted Gen 1 and Gen 2 species pool without BST or evolution-stage limits. |

`START LEG` excludes legendary and mythical Pokémon by default. `ALLOW`
adds them to the `CHAOS` pool. Balanced starters remain base-stage Pokémon, so
the legendary option does not weaken that mode's evolution-stage rule.

The Ball preview shows the replacement's front sprite, name, and cry before
confirmation, and the received level 5 Pokémon is the same one shown. The
normal mandatory-nickname and gift encounter policies still apply.

Gold's rival continues to steal the starter from the original counter slot.
That slot now contains its randomized species. Later rival battles advance
through the replacement's first evolution path when one exists. The trainer
randomizer never replaces this synchronized starter line, although it may
replace the rival's other party members when enabled.

## Gift randomization

`GIFT MON` randomizes Gold's scripted gift Pokémon, Togepi's Egg, Game Corner
Pokémon prizes, and Mania's Shuckie. Each replacement is deterministic for the
run and uses the same `BALANCED` and `CHAOS` rules as the other species
randomizers.

| Gift source | Preserved behavior |
| --- | --- |
| Eevee, Kenya, and Tyrogue | Authored level, held item, mail, and script progression. |
| Togepi's Egg | Egg state, hatch timing, mandatory naming, Pokédex registration, and the Togepi hatch story event. |
| Game Corner Pokémon | Coin price, authored level, menu label, and purchase flow. |
| Shuckie | Level, Berry, nickname, Mania's ownership, and the return-or-keep event. |

Scripted Eggs always map to a nonlegendary, hatchable base-stage species. This
restriction applies even when `GIFT LEG` is set to `ALLOW`. The legendary
setting affects non-Egg gifts only.

The `GIFTS` Nuzlocke policy remains independent. `GIFT MON` decides which
species is received, while `GIFTS` decides whether receiving it consumes the
area's encounter. Day-Care breeding Eggs are governed by `BREEDING` and are
not species-randomized by this feature.

## Trainer randomization

`TRAINERS` randomizes every eligible trainer party slot using the stable run
seed, trainer class, trainer member, and party position. Fighting or rematching
the same trainer does not reroll its team.

| Mode | Behaviour |
| --- | --- |
| `OFF` | Preserves Gold's original trainer species. |
| `BALANCED` | Replaces each slot with a similar-BST Pokémon at the same evolution stage. |
| `CHAOS` | Replaces each slot from the complete permitted Gen 1 and Gen 2 species pool. |

Party size, held items, fixed trainer DVs, and the level entering the
randomizer are preserved. If level scaling is enabled, it determines that
level first. Each replacement then receives the latest four level-up moves it
can legally know at that final level, replacing moves authored for the original
species.

`TRAIN LEG` excludes legendary and mythical replacements by default.
`ALLOW` adds them to the available pool. Balanced mode still requires its
evolution-stage and similar-BST match.

`BOSSES` includes Gym Leaders, the rivals, Elite Four, Champion Lance, Kanto
leaders, Blue, and Red. `EXCLUDE` preserves those teams while ordinary trainers
continue to randomize. The rival's starter line always remains synchronized
with the separately configured starter randomizer, even when boss trainer
randomization is excluded.

## Item randomization

`ITEMS` randomizes every item the overworld hands over: itemballs lying in the
overworld, hidden items found with A or the ITEMFINDER, items given by NPCs,
the fruit picked from berry trees, and the TMs awarded for beating a Gym
Leader. The replacement is keyed to the
run seed, the map, the script's object, and the original item, so re-reading a
script never rerolls its reward.

| Mode | Behaviour |
| --- | --- |
| `OFF` | Preserves Gold's original items. |
| `BALANCED` | Replaces each item with one of a similar price. |
| `CHAOS` | Replaces each item from the complete permitted item pool. |

TMs are only ever replaced by other TMs, so the machine pool stays intact.
Quantities are preserved.

> [!NOTE]
> Key items and HMs are never randomized, in either direction: they are never
> replaced and never appear as a replacement, so no run can be made
> unfinishable. The Bug-Catching Contest's PARK BALL and the unused item rows
> are excluded from the pool for the same reason. APRICORN trees also keep
> their own apricorn, so Kurt's custom Balls stay reachable; ordinary berry
> trees are randomized, and each tree keeps one fruit for the whole run.

## Encounter rules

### When the Nuzlocke begins

The run begins permanently when the player first owns **any item from the Ball
pocket**. Encounters seen before that moment never consume or fail an area.
This is a hard rule and cannot be disabled.

At that same moment, every configured rule becomes read-only for the rest of
the run. Saving, reloading, spending every Ball, or losing every Ball does not
unlock the ruleset.

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

### Roaming Pokémon

Raikou, Entei, and Suicune are tracked as persistent roaming encounters rather
than encounters for whichever route they happen to appear on.

| Outcome | Roaming encounter result |
| --- | --- |
| Roamer appears | The current route remains available. |
| Roamer flees | Its roaming encounter remains active. |
| Player runs | Its roaming encounter remains active. |
| Roamer is caught | Its roaming encounter is completed. |
| Roamer is defeated | Its roaming encounter is permanently failed. |

Each Gold roaming slot has its own allocation. Route limits, the dupes clause,
and static encounter policy do not apply. Tracking uses the roaming slot rather
than a species list, so randomized roaming species will retain the correct rule.

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

### Bred Eggs

Day-Care breeding has a separate policy from scripted gift Eggs such as
Togepi. This closes the unlimited breeding loophole without preventing the Day
Care from raising deposited Pokémon.

| Policy | Behaviour |
| --- | --- |
| `FORBID` | Parents can be deposited and raised, but cannot produce or hand over Eggs. |
| `AREA` | The first collected Egg consumes the Day-Care landmark. No further bred Eggs can be produced or collected. |
| `BONUS` | Preserves Gold's unrestricted repeat breeding without consuming an area. |

An AREA Egg is recorded only after it successfully enters the party. A full
party or blocked collection leaves the Egg retryable and does not consume the
landmark.

## Permadeath and run endings

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

### Successful-run report

Defeating Red completes the Nuzlocke exactly once. After the battle finishes,
the completion screen shows the surviving final party alongside the run's
badges, play time, catches, failed encounters, and memorial.

- `A` continues playing without deleting the save.
- `B` returns to the title without deleting the save.
- Red rematches cannot complete or report the same run again.

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

Wild Pokémon and trainers are scaled separately. `WILD LVL` and
`TRAINER LVL` each set how far below the party maximum that group aims, in
steps of 5% from `-0%` to `-50%` (both default to `-20%`). A smaller percentage
means tougher opponents. For ordinary wild Pokémon and trainers, the target is:

```text
floor(highest party level × (100% - scale)) + random variance from -2 to +2
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
| Current mod version | 0.23.0 |

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
