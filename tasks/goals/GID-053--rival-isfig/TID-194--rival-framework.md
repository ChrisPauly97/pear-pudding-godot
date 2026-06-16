# TID-194: Rival Framework — Encounter Tiers, Decks, Save Fields

**Goal:** GID-053
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The foundational layer for the rival system. Three EnemyData resources define Isfig's deck at each encounter tier, persisted as flags in SaveManager. A tier-selection function at battle start nudges the deck choice based on player level.

## Research Notes

- **Three rival deck resources** in `data/enemies/`:
  - `rival_isfig_1.tres` — Tier 1 (Encounter 1, after `chapter1_left_madrian`). Difficulty tier 1, ~8 cards (Ghost, Skeleton, basic spells). Display name "Isfig". Mark `is_boss: false`.
  - `rival_isfig_2.tres` — Tier 2 (Encounter 2, after `chapter1_received_letter`). Difficulty tier 2, ~10 cards (Skeleton, Zombie, some tactical spells). Display name "Isfig the Pursuing". Mark `is_boss: false`.
  - `rival_isfig_3.tres` — Tier 3 (Encounter 3 / Final Showdown, after `chapter1_reached_blancogov` + `chapter1_temple_council`). Difficulty tier 3, ~10 cards (Zombie, Ghoul, advanced spells). Display name "Isfig, Maiteln's Shadow". Mark `is_boss: false`.
  - Each `.tres` file follows the `EnemyData` schema (cite **autoloads/SaveManager.gd** line 29–31 and **data/EnemyData.gd** — `id`, `display_name`, `deck: PackedStringArray`, `drop_pool`, `coin_reward: int`, `difficulty_tier: int`, `is_boss: bool`, `boss_hp: int = 0`, `phase2_deck: PackedStringArray = []`).
  - **CLAUDE.md rule** (`.tres` file UIDs): Create a sidecar `.uid` file for each, format `uid://` + 12 random alphanumeric chars (lowercase). Example from **data/enemies/undead_basic.tres** (line 1): `uid="uid://iugru6ekzfxi"`. Generate via `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`.
  - Register all three in **autoloads/EnemyRegistry.gd** — the registry auto-loads all `.tres` files from `data/enemies/` via `_ensure_loaded()` (lines 16–31), so no manual registration is required.

- **SaveManager fields** — add to **autoloads/SaveManager.gd** (expand `# Progression signals` section around line 95):
  - `rival_encounters_won: int = 0` — count of rival encounters the player has beaten (0, 1, or 2 before final showdown).
  - `rival_defeated: bool = false` — set to true after the final showdown; guards the unique card reward (grant it only once).
  - Integrate into **_migrate()** at an appropriate version (cite current save version from migration table, **docs/agent/save-system.md** line 106 shows v14 is `pending_battle_state`; next version will be v15). In `_migrate()`, backfill old saves: `if not data.has("rival_encounters_won"): data["rival_encounters_won"] = 0` and `if not data.has("rival_defeated"): data["rival_defeated"] = false`. Update the migration history table in `docs/agent/save-system.md` to note v15 added rival fields.

- **Level-based tier nudge** — a pure function in a new file **game_logic/RivalSystem.gd**:
  ```gdscript
  extends Node
  
  const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
  
  ## Given SaveManager.level and rival encounter count, return the EnemyData type ID to use.
  ## Escalates encounter tier based on wins, with player level as a secondary boost.
  static func get_rival_type(encounters_won: int, player_level: int) -> String:
      var base_tier: int = clamp(encounters_won, 0, 2)  # 0, 1, or 2 (indices into deck list)
      # Level nudge: if player_level > (base_tier + 1) * 5, bump to next tier (max tier 2).
      if player_level > (base_tier + 1) * 5 and base_tier < 2:
          base_tier += 1
      var tier_ids: Array[String] = ["rival_isfig_1", "rival_isfig_2", "rival_isfig_3"]
      return tier_ids[base_tier]
  ```
  Decision note: Simple per-encounter bump, no per-card stat rerolling. Player level only affects tier selection once, at battle start, not dynamically during the battle.

- **GameBus signal** (optional, for dialogue/toast feedback) — cite **autoloads/GameBus.gd** line 24 (`story_flag_set`). If the rival system needs to trigger a toast or HUD message on a win, emit a new signal `rival_defeated(encounter_num: int)` (optional; may not be needed if victory flows through `battle_won` alone).

- **Headless tests** — in **tests/test_rival.gd**:
  - Test `get_rival_type()` pure function: given (encounters_won=0, level=1) returns "rival_isfig_1"; (0, 8) returns "rival_isfig_2" (nudge); (1, 1) returns "rival_isfig_2"; (2, 1) returns "rival_isfig_3".
  - Test SaveManager round-trip: set `rival_encounters_won=1, rival_defeated=false`, save, load a fresh SaveManager, verify fields persist.
  - Test deck registration: call `EnemyRegistry.get_deck("rival_isfig_1")`, expect non-empty array.

- **No changes to docs yet** — this is framework only. See TID-196 for final journal integration doc updates.

## Plan

1. Create `data/enemies/rival_isfig_1.tres` + `.uid` (Tier 1, 8 cards, difficulty 1)
2. Create `data/enemies/rival_isfig_2.tres` + `.uid` (Tier 2, 10 cards, difficulty 2)
3. Create `data/enemies/rival_isfig_3.tres` + `.uid` (Tier 3, 10 cards, difficulty 3)
4. Add three `const _E_RIVAL_ISFIG_*` preloads + dict entries to `autoloads/EnemyRegistry.gd`
5. Create `game_logic/RivalSystem.gd` with `get_rival_type(encounters_won, player_level) -> String`
6. Add `rival_encounters_won: int` and `rival_defeated: bool` to `SaveManager.gd` with migration v30 and load/save/new_game wiring
7. Add optional `rival_encounter_won(encounter_num: int)` signal to `GameBus.gd`
8. Create `tests/unit/test_rival.gd` (pure-function and migration tests)
9. Register test suite in `tests/runner.gd`

## Changes Made

- Created `data/enemies/rival_isfig_1.tres` + `.uid` — Tier 1 Isfig deck (8 cards, difficulty 1, "Isfig")
- Created `data/enemies/rival_isfig_2.tres` + `.uid` — Tier 2 deck (10 cards, difficulty 2, "Isfig the Pursuing")
- Created `data/enemies/rival_isfig_3.tres` + `.uid` — Tier 3 deck (10 cards, difficulty 3, "Isfig, Maiteln's Shadow")
- `autoloads/EnemyRegistry.gd`: added 3 preload constants for APK packaging; added rival entries to `_enemies` dict in `_ensure_loaded()`
- Created `game_logic/RivalSystem.gd`: static `get_rival_type(encounters_won, player_level)` with level-nudge logic
- `autoloads/SaveManager.gd`: added `rival_encounters_won: int` and `rival_defeated: bool` fields; bumped CURRENT_SAVE_VERSION to 30; added `_migrate_v29_to_v30`; wired fields into `new_game()`, `load_save()`, `save()`; added `record_rival_win()` and `set_rival_defeated()` helpers
- `autoloads/GameBus.gd`: added `rival_encounter_won(encounter_num: int)` signal
- Created `tests/unit/test_rival.gd`: 20 tests covering `get_rival_type`, SaveManager fields, migration, and EnemyRegistry registration
- `tests/runner.gd`: registered `test_rival.gd` in SUITES

## Documentation Updates

Save-system doc (`docs/agent/save-system.md`) is significantly out of date (last updated to v16; actual version is now 30). Updated below with the rival fields entry. Full migration history catch-up is deferred to GID-075 (dead code / docs hygiene).
