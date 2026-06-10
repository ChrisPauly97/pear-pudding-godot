# TID-218: Capture-Condition Fields on EnemyData + In-Battle Condition Tracking

**Goal:** GID-061
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The data and logic layer for Soulbinding. Extends the `EnemyData` resource with `signature_card` / `capture_condition` / `capture_param` fields, exposes them through `EnemyRegistry`, and adds a pure-logic `CaptureTracker` in `game_logic/battle/` that observes battle events and answers "was the capture condition satisfied?" at game-over. TID-219 consumes the verdict in the victory flow; TID-220 authors the per-enemy content.

## Research Notes

### EnemyData resource

- Script: `data/EnemyData.gd` — `extends Resource` (no `class_name`; consumers preload it, e.g. `const EnemyData = preload("res://data/EnemyData.gd")` at line 3 of `autoloads/EnemyRegistry.gd`).
- Current exports: `id: String`, `display_name: String`, `deck: PackedStringArray`, `drop_pool: PackedStringArray`, `coin_reward: int = 5`, `is_boss: bool`, `boss_hp: int`, `phase2_deck: PackedStringArray`, `difficulty_tier: int = 1`.
- Add: `@export var signature_card: String = ""`, `@export var capture_condition: String = ""`, `@export var capture_param: int = 0`. Empty `signature_card` means "no signature" — all existing `.tres` files stay valid without edits (Godot defaults missing properties).
- The 4 enemy `.tres` files: `data/enemies/undead_basic.tres`, `undead_horde.tres`, `ghoul_pack.tres`, `undead_elite.tres` (each has a `.tres.uid` sidecar already). Content authoring is TID-220 — this task only adds the fields.

### EnemyRegistry accessors

- `autoloads/EnemyRegistry.gd` is all `static func`s following one pattern per field, e.g. `get_drop_pool(type_id)` (line 45), `get_coin_reward(type_id)` (line 55), `get_difficulty_tier(type_id)` (line 107). Add `get_signature_card(type_id) -> String`, `get_capture_condition(type_id) -> String`, `get_capture_param(type_id) -> int` in the same style.
- Useful for TID-219's shop exclusion: also add `static func get_all_signature_card_ids() -> Array[String]` iterating loaded enemies.

### Condition vocabulary (final set decided in Plan; these 4 are verified trackable)

| Condition key (suggested) | Meaning | Param |
|---|---|---|
| `spell_final_blow` | The final blow that destroyed the enemy's **last** board minion was a spell | — |
| `hero_hp_at_most` | Win with the player hero at or below N HP | N |
| `no_minion_hero_attacks` | Win without ever attacking the enemy hero with a minion | — |
| `win_by_turn` | Win before/at `GameState.turn_number` N | N |

### Critical finding: GameBus battle signals are declared but never emitted

- `autoloads/GameBus.gd` declares `card_played(card_id, zone, slot)` (line 16), `card_attacked(attacker_id, target_id)` (line 17), `battle_ended(winner)` (line 19) — **grep confirms zero `.emit()` sites for all three**. Only `turn_ended` is emitted, from `game_logic/battle/GameState.end_turn()` (line 39, via `Engine.get_main_loop()` → `get_node_or_null("GameBus")` since GameState is a RefCounted).
- The docs (`docs/agent/battle-system.md`, GID-045 acceptance criteria) assume these signals work — part of this task is emitting them for real at the BattleScene action sites, then having `CaptureTracker` subscribe. Alternative (acceptable if signal payloads prove insufficient): BattleScene calls tracker methods directly; either way, document the choice.

### BattleScene action sites to instrument (`scenes/battle/BattleScene.gd`)

- Player minion → enemy minion attack: `_on_enemy_card_input()` (line 1093).
- Player minion → enemy hero attack: `_on_enemy_hero_input()` (line 1129). This is the site for `no_minion_hero_attacks` (only player-side minion-to-hero attacks count).
- Spells: `_resolve_spell_effect(card, caster_pid, explicit_target)` (line 1258) — handles player targeted (lines 718/735), player non-targeted (line 388), and AI/auto (line 1384 via `_flush_auto_spells`). For `spell_final_blow`: after a player-cast (`caster_pid == 0`) spell resolves, check if the enemy board went from ≥1 minion to 0 minions and the enemy hero was already in a state where that was their last minion — compare `_state.players[1].board` occupancy before/after the spell (BattleScene already snapshots HP around spells via `_snapshot_hp_positions()`, line 1724; board-count snapshot is analogous).
- Turn count: `GameState.turn_number` (`game_logic/battle/GameState.gd` line 8) increments on **every** `end_turn()` — i.e. per half-round, not per full round. Player turns are odd numbers (player starts). Define `win_by_turn` against this and document it.
- Game over: `_check_game_over()` (line 1446) — winner 0 path is where TID-219 will query the tracker (and where `hero_hp_at_most` is evaluated against `_state.players[0].hero.health`).
- AI turn: `_run_ai_turn()` (line 1198) / `_execute_ai_actions()` (line 1206) — AI actions must NOT count against player-only conditions; key tracker events by acting player.

### CaptureTracker design

- New file `game_logic/battle/CaptureTracker.gd`, `extends RefCounted`, pure logic, no rendering — same style as `GameState.gd` / `PlayerState.gd`. Per CLAUDE.md, consumers must `preload` it (`const CaptureTracker = preload("res://game_logic/battle/CaptureTracker.gd")`) — do not rely on `class_name`.
- Constructed by BattleScene in `_ready()` with `(capture_condition, capture_param)` from `enemy_data` (see below). API sketch: `note_minion_attacked_hero(attacker_pid)`, `note_spell_resolved(caster_pid, enemy_board_before, enemy_board_after)`, `is_satisfied(state: GameState) -> bool` (evaluates end-state conditions like `hero_hp_at_most` / `win_by_turn` plus accumulated flags), `condition_text() -> String` for UI (TID-219).
- `enemy_data` dict reaching BattleScene: built in `EnemyNPC.engage()` (`scenes/world/entities/EnemyNPC.gd` line 73) with keys `enemy_type`, `enemy_deck`, `is_boss`, `boss_hp`, `phase2_deck`, `id`, `alive`; injected via `SceneManager._on_enemy_engaged()` (line 226: `_battle_overlay.enemy_data = enemy_data`). Either add `signature_card`/`capture_condition`/`capture_param` to the dict in `engage()`, or (simpler, fewer dict keys) have BattleScene call `EnemyRegistry.get_capture_condition(str(enemy_data.get("enemy_type", "")))` directly — BattleScene already does exactly this for drop pools at line 1452–1453.
- Mid-battle persistence (GID-034): leaving a battle serializes `GameState` into `SaveManager.pending_battle_state` and restores via `GameState.from_dict()` in `BattleScene._ready()`. Tracker flags (`no_minion_hero_attacks` violated yes/no, etc.) are extra state — either add a small `capture_tracker` sub-dict alongside the GameState dict in `pending_battle_state`, or accept that a fled-and-resumed battle resets/voids the capture (document whichever; precedent: `_hero_power_used` is knowingly not persisted, see `docs/agent/battle-system.md` "Note").

### Constraints

- GDScript Variant-inference rules per CLAUDE.md (explicit types for `max/min/clamp/array[i]`; `assign()` for dict-sourced typed arrays — see `_check_boss_phase2()` line 1419 for the in-file pattern).
- No new `.tres`/`.gdshader` resources in this task → no `.uid` sidecars needed; new `.gd` files manage UIDs internally.
- Tests: add `tests/test_capture_tracker.gd` wired into `tests/runner.gd` — cover each condition key (satisfied + violated paths), AI actions not counting against player conditions, and unknown/empty condition returning false. Run with `godot --headless --path . -s tests/runner.gd`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
