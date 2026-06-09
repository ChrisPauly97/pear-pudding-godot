# TID-194: Rival Framework — Encounter Tiers, Decks, Save Fields

**Goal:** GID-053
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
