# GID-059: Battlefield Resonance — Where You Fight Matters

## Objective

Battles inherit the location and time of day where the encounter happens — each biome applies one visible board rule and time of day modifies Dawn/Dusk card costs.

## Context

The world has 5 distinct biomes (`game_logic/world/BiomeDef.gd`: GRASSLANDS=0, FOREST=1, DESERT=2, SCORCHED=3, MOUNTAINS=4) and a full day/night cycle (`WorldScene._time_of_day`, persisted as `SaveManager.time_of_day`), but battles are identical everywhere and at all times. Cards already carry `magic_branch` ("ember" / "dawn" / "dusk" / "ash") yet the branches have no situational meaning. This goal makes location and time mechanically matter:

**Biome board rules (one per biome, always visible in battle):**
- **Grasslands** — the first card played each turn costs 1 less (floor 0).
- **Forest** — board slots 0 and 4 (edges) grant Shroud to minions placed there.
- **Desert** — at turn start during daytime, the leftmost minion on each board takes 1 scorch damage.
- **Scorched** — all damage is +1.
- **Mountains** — center slot (index 2) grants Ward to minions placed there.

**Time-of-day rule (applies in every biome):**
- At night, Dusk-branch cards (`magic_branch == "dusk"`) cost 1 less (floor 0); during day, Dawn-branch cards cost 1 less. Night is when `sin((time_of_day - 0.25) * TAU) < 0`, i.e. `time_of_day < 0.25 or > 0.75` (same predicate as GID-055 night hunts).

Biome + time are captured at the moment `GameBus.enemy_engaged` fires and travel inside `enemy_data` into the battle. Named maps / dungeons (`WorldScene._is_infinite == false`) can use a neutral "dungeon" ruleset or no board rule — this is a design decision deferred to the Plan phase of TID-212.

Rules are data-driven — a const rules table (or `BattlefieldRules` resource) in `game_logic/battle/` keyed by biome id — and surfaced in BattleScene with a battlefield banner, rule text, and affected-slot highlights.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-212 | Battlefield rules data model + capture biome/time at enemy_engaged | agent | done | — |
| TID-213 | BattleScene UI: battlefield banner, rule text, affected-slot highlights | agent | done | TID-212 |
| TID-214 | Balance pass + headless tests for all biome/time rules | agent | done | TID-213 |

## Acceptance Criteria

- [ ] `enemy_data` passed into BattleScene carries the biome id and time-of-day (or a derived `is_night` flag) captured when `GameBus.enemy_engaged` fired; the values survive mid-battle save/resume via `SaveManager.pending_battle_enemy_data`.
- [ ] A data-driven rules table in `game_logic/battle/` maps each of the 5 biomes to exactly one board rule; battle logic reads the table, never hard-codes per-biome behaviour at call sites.
- [ ] Grasslands: the first card played by either player each turn costs 1 less (floor 0); mana display and AI affordability both respect the discount.
- [ ] Forest: a minion placed in slot 0 or 4 (either board) gains Shroud (`shroud_active = true`) on placement.
- [ ] Desert: at the start of each player's turn while it is daytime in the captured context, the leftmost (lowest-index) minion on each board takes 1 damage, with floating-number/flash feedback.
- [ ] Scorched: every damage event (minion combat, hero hits, spells, emergence, status ticks per Plan-phase decision) deals +1 damage.
- [ ] Mountains: a minion placed in slot 2 (either board) gains Ward and is treated as a Ward target by `_get_ward_valid_targets()` and `BasicAI`.
- [ ] Dawn/Dusk cost modifier: at night Dusk-branch cards cost 1 less, during day Dawn-branch cards cost 1 less (floor 0), shown on the card face in hand.
- [ ] Battles started on named maps / dungeons use the neutral ruleset decided in the Plan phase (no biome rule or a "dungeon" rule) and never crash on missing biome context.
- [ ] BattleScene shows a battlefield banner at battle start (biome name + rule text + day/night indicator) and persistently highlights affected slots (Forest edges / Mountains center).
- [ ] AI (`BasicAI`) plays correctly under all rules — no illegal plays, no mana underflow, Ward targeting honoured for rule-granted Ward.
- [ ] Headless tests cover every biome rule, both time-of-day cost modifiers, the floor-0 cost clamp, and the neutral dungeon path; `godot --headless --path . -s tests/runner.gd` exits 0.
- [ ] `docs/agent/battle-system.md` and `docs/agent/signals-and-constants.md` updated to document the new context fields and rules table.
