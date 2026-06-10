# TID-214: Balance pass + headless tests for all biome/time rules

**Goal:** GID-059
**Type:** agent
**Status:** pending
**Depends On:** TID-213

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With the rules (TID-212) and UI (TID-213) in place, this task locks the system down: headless unit tests for every biome rule, both time-of-day cost modifiers, the floor-0 clamp, stacking behaviour, persistence across mid-battle save/resume, and the neutral dungeon path — plus a balance pass tuning any rule that proves degenerate (e.g. Scorched +1 with cheap damage spells, Desert scorch repeatedly killing 1-HP minions).

## Research Notes

**Test infrastructure (verified):**
- Runner: `tests/runner.gd` — `extends SceneTree`, a `const SUITES: Array = [preload(...), ...]` list, `_initialize()` instantiates each suite, calls `get_suite_name()` and `run_all()`, sums `pass_count` / `fail_count` / `pending_count`, exits 1 on any failure. **A new suite file must be added to the `SUITES` preload list** (e.g. `preload("res://tests/unit/test_battlefield_rules.gd")`).
- Run command: `godot --headless --path . -s tests/runner.gd` (exit 0 = pass). Install per CLAUDE.md "Running Tests" if `godot` is absent (wget Godot 4.4.1 zip → /usr/local/bin/godot).
- Framework: `tests/framework/test_case.gd`; suites extend it: `extends "res://tests/framework/test_case.gd"`. Existing battle suites to mimic: `tests/unit/test_game_state.gd`, `test_player_state.gd`, `test_zone_state.gd`, `test_status_effects.gd`, `test_basic_ai.gd` (14 suites total).
- Pattern from `test_game_state.gd`: tests are `func test_*() -> void` using `assert_eq(...)`; helpers build raw card template dicts directly — `_tmpl(id, cost, attack, health)` returns `{"id":..., "name":..., "cost":..., "attack":..., "health":..., "card_class":"minion", "description":""}` and `CardInstance.new(_tmpl(...))` builds cards without CardRegistry. Add `"magic_branch": "dusk"`/`"dawn"` keys for cost-modifier tests (verify the exact template key consumed by `CardInstance._init` before writing tests). The `--path .` flag makes autoloads (CardRegistry, GameBus, IsoConst) available; `GameState.new()` needs CardRegistry.
- The runner is pure logic-level — no scenes are instantiated, so tests target `game_logic/battle/*` (BattlefieldRules table, GameState/PlayerState behaviour), NOT BattleScene UI. Whatever damage/cost hooks TID-212 placed in BattleScene-only code cannot be covered headlessly — if the Plan put logic there, prefer moving the testable parts into `game_logic/battle/` during this task.

**What to test (one or more cases each):**
1. **Rules table integrity** — every biome id 0–4 (`BiomeDef.GRASSLANDS..MOUNTAINS`, `game_logic/world/BiomeDef.gd`) has exactly one rule entry + rule text; biome −1 / "dungeon" returns the neutral rule without error.
2. **Grasslands** — first `play_card` of a turn costs `cost - 1`; second costs full; flag resets on `start_turn` / `end_turn`; floor 0 for 0-cost cards; AI affordability via `PlayerState.can_play()` (used by `ai/BasicAI.gd` lines 16/65) reflects the discount.
3. **Forest** — minion entering slot 0 or 4 gains Shroud (`card.keywords.has(Keywords.SHROUD)` and/or `shroud_active == true`); slots 1–3 do not. Note `ZoneState.add_card` fills `first_empty_slot()` (`ZoneState.gd` line 25) — fill slots to force edge placement in tests. First hit absorbed via `CardInstance.take_damage()`.
4. **Desert** — turn-start tick damages the lowest-index minion on each board by 1 when context is daytime; no tick at night; empty board safe; minion at 1 HP dies and moves to discard via the normal removal path.
5. **Scorched** — damage events deal +1 per the scope decided in TID-212 (combat, spells, emergence; confirm decided behaviour for poison/scorch ticks and test exactly that); a 1-attack minion deals 2.
6. **Mountains** — minion entering slot 2 gains Ward; `BasicAI.decide_turn()` targets it first (`ward_targets` logic) and never targets the hero while it lives.
7. **Time-of-day cost** — night (`time_of_day < 0.25 or > 0.75`, predicate `sin((t - 0.25) * TAU) < 0` per GID-055): dusk-branch card cost −1, dawn unchanged; day: dawn −1, dusk unchanged; floor 0; stacking with Grasslands follows the TID-212-defined order; boundary values 0.25 / 0.75 behave consistently with the predicate.
8. **Persistence** — `GameState.to_dict()` → `from_dict()` round-trip preserves battlefield context (and Grasslands per-turn flag if serialised); rule-granted keywords survive via `CardInstance.to_dict()` (already serialises `keywords`, `shroud_active` — docs/agent/battle-system.md "Mid-Battle State Persistence").
9. **Neutral path** — `GameState` with no/neutral context behaves exactly like pre-GID-059 (no discounts, no slot keywords, no scorch, +0 damage).

**Balance pass:**
- Reference stats: starter minions Ghost/Skeleton/Zombie/Ghoul (cost 1–4 band); keyword cards table in docs/agent/battle-system.md (TID-096) — e.g. Surge Spirit 2-mana 3/1 becomes lethal fast under Scorched +1; Iron Revenant 3-mana 1/5 Ward in Mountains slot 2 gets redundant Ward (must be a no-op, not a crash, if the keyword is already present).
- Desert: 1-HP minions (Surge Spirit) die instantly in leftmost slot — acceptable as a positioning tax, but verify the AI doesn't lock itself into feeding minions; `BasicAI` always plays into `first_empty_slot()`, i.e. leftmost — flag in the balance writeup if Desert overly punishes the AI.
- Scorched + `deal_damage_all` spells: check no spell becomes an unconditional board wipe at its cost (spell list + powers in docs/agent/battle-system.md "Card Data"). Tuning levers: per-rule magnitudes in the rules table (that's why it's data-driven).
- Document chosen tunings and any rule-text changes; keep rule text in the table so TID-213 UI updates automatically.

**Constraints (CLAUDE.md):**
- Explicit types where RHS is Variant (`var d: int = arr[i]`); typed arrays for deck literals (`var deck: Array[String] = [...]`).
- Preload pattern in tests: `const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")` — never rely on `class_name` global visibility for newly created files.
- New `.gd` test files need no `.uid` sidecar (scripts manage UIDs internally), but the suite must be registered in `tests/runner.gd` `SUITES`.
- Update `docs/agent/battle-system.md` (rules table, context fields, test coverage) and add the GID-059 row context to `docs/agent/signals-and-constants.md` if `enemy_engaged` payload changed.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
