# TID-197: Siege Model & State

**Goal:** GID-054
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The pure data model and logic for siege triggering, gauntlet progression, hero HP carry-over between battles, and save persistence. All state is managed in SaveManager with a new autoload helper (`SiegeDefs.gd`) containing pure static predicates and enemy roster.

## Research Notes

- **New script:** `game_logic/SiegeDefs.gd` (no class_name, used via preload). Pure static helpers; no instance state:
  - `should_trigger(flags: Dictionary, days_elapsed: int, last_siege_day: int, world_seed: int) -> bool` — evaluates the three conditions:
    1. **Gating flag:** `flags.get("chapter1_warned_farsyth", false)` must be true (matches the real mid-chapter flag from **docs/agent/story-implementation.md** line 41, which is set when the player speaks to Lord Farsyth in `farsyth_mansion`). Before this flag, zero sieges fire.
    2. **Cooldown:** `days_elapsed - last_siege_day >= 4` (at least 4 in-game days since the last siege; `last_siege_day` is initialized to 0 on new game, so the first siege can trigger on or after day 4).
    3. **Determinism:** `hash(world_seed ^ days_elapsed) % 100 < SIEGE_SPAWN_CHANCE` (currently 8 = ~8% per-day probability, seeded via the world seed XOR'd with the current day to make the same save+day always trigger the same outcome — matches the pattern used in **InfiniteWorldGen.seed_rng()** for chunk determinism, verified in **docs/agent/world-generation.md**).
  - Returns true only if all three are satisfied. Called on map load (from WorldScene when entering a town).
  - `get_raider_deck_ids(stage: int) -> Array[String]` — returns the card IDs for raider deck stage 0/1/2 (increasing difficulty: tier 1 → 2 → 3). Uses seeded RNG via world_seed to shuffle the pool so different saves get different decks.
  - `get_stage_name(stage: int) -> String` — returns `"Wave 1 of 3"`, `"Wave 2 of 3"`, or `"Wave 3 of 3"` for interstitial text.
  - `SIEGE_SPAWN_CHANCE: int = 8` — probability %.

- **Three raider EnemyData resources** in `data/enemies/`:
  - `martarquas_raider_1.tres` — difficulty_tier 1, deck pool of 4–5 mid-tier ghoul/undead cards, ~40 HP total.
  - `martarquas_raider_2.tres` — difficulty_tier 2, 5–6 cards, ~60 HP total.
  - `martarquas_raider_3.tres` — difficulty_tier 3, 6–7 cards, ~80 HP total.
  - All three are registered in **autoloads/EnemyRegistry.gd** via preload + array registration (follow the existing pattern in EnemyRegistry; cite the exact registration lines when implementing).
  - Create companion `.uid` files for each `.tres` (format: `uid://[12 lowercase alphanumeric]`, generated via `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`). See **CLAUDE.md: Godot Resource .uid Files** section.

- **SaveManager fields** (append to existing structure around line 100):
  - `siege: Dictionary = {}` — active siege state; structure: `{ town: String, stage: int, hero_hp: int, day_started: int }`. Empty dict `{}` means no active siege.
  - `last_siege_day: int = 0` — the `days_elapsed` value when the last siege ended (win or loss); used in cooldown check.
  - Add both to `_migrate()` (e.g., after line 121 in **autoloads/SaveManager.gd**) with defaults: `siege = {}`, `last_siege_day = 0`.
  - **Migration version:** Next version is 31 (current was 30). Added `_migrate_v30_to_v31()`.
  - Methods:
    - `start_siege(town: String) -> void` — sets `siege = { town, stage: 0, hero_hp: 30, day_started: days_elapsed }` and marks dirty.
    - `get_active_siege() -> Dictionary` — returns `siege` (or empty dict if none).
    - `advance_siege_stage() -> void` — increments `stage` from 0 to 1 to 2 and marks dirty.
    - `set_siege_hero_hp(hp: int) -> void` — updates `siege["hero_hp"]` = hp.
    - `end_siege_victory() -> void` — sets `last_siege_day = days_elapsed`, calls `apply_town_discount(town)`, clears `siege = {}`, marks dirty.
    - `end_siege_defeat() -> void` — sets `last_siege_day = days_elapsed`, clears `siege = {}`, marks dirty (no discount).

- **Carry-over HP injection:** `BattleScene._ready()` checks `get_active_siege()` after building the fresh battle state. If active, sets `_state.players[0].hero.health` and `max_health` to `siege["hero_hp"]`.

- **Gauntlet chaining via SceneManager:** `_on_battle_won()` checks active siege. If stage < 2: advance stage, save, show interstitial, chain next raider. If stage == 2: apply victory rewards, end_siege_victory.

- **Tests (headless):**
  - `tests/unit/test_siege_trigger.gd` — SiegeDefs.should_trigger with all three conditions.
  - `tests/unit/test_siege_state.gd` — SaveManager siege methods + v30→v31 migration.

## Plan

1. Create `game_logic/SiegeDefs.gd` with static helpers.
2. Create 3 enemy .tres + .uid files and register in EnemyRegistry.
3. Add siege/last_siege_day/town_discounts fields to SaveManager (version 31 migration).
4. Add SaveManager siege methods and increment_day cleanup.
5. Inject carry-over HP in BattleScene._ready().
6. Add gauntlet chaining in SceneManager._on_battle_won() and defeat in _on_battle_lost().
7. Write test_siege_trigger.gd and test_siege_state.gd.

## Changes Made

- Created `game_logic/SiegeDefs.gd` — pure static helpers: `is_siege_town`, `should_trigger`, `get_raider_deck_ids`, `get_stage_name`, `TOWN_GATES`, `SIEGE_SPAWN_CHANCE`.
- Created `data/enemies/martarquas_raider_1.tres` + `.tres.uid` (uid://0i2e393oih8e).
- Created `data/enemies/martarquas_raider_2.tres` + `.tres.uid` (uid://kv17w0a15hxg).
- Created `data/enemies/martarquas_raider_3.tres` + `.tres.uid` (uid://ebapu6cjbjw2).
- Updated `autoloads/EnemyRegistry.gd` — 3 preload consts + 3 dict entries in `_ensure_loaded()`.
- Updated `autoloads/GameBus.gd` — added `signal siege_victory` and `signal siege_defeated(coins_lost: int)`.
- Updated `autoloads/SaveManager.gd` — version 31, new fields (`siege`, `last_siege_day`, `town_discounts`), `_migrate_v30_to_v31()`, all siege/discount methods, `increment_day()` siege timeout and discount cleanup.
- Updated `scenes/battle/BattleScene.gd` — siege HP injection in `_ready()` after Spire HP injection.
- Updated `autoloads/SceneManager.gd` — gauntlet chaining in `_on_battle_won()`, defeat consequence in `_on_battle_lost()`, `_apply_siege_victory_rewards()`, `_show_siege_interstitial()`, `town_name` passed to ShopScene.
- Created `tests/unit/test_siege_trigger.gd` + `.uid`.
- Created `tests/unit/test_siege_state.gd` + `.uid`.

## Documentation Updates

- Created `docs/agent/town-siege.md` covering all siege systems.
- Updated `tests/runner.gd` to include 5 new siege test suites.
