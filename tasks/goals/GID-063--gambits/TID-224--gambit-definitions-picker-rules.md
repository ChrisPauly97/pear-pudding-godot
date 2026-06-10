# TID-224: Gambit definitions, pre-battle picker UI, rule application in GameState

**Goal:** GID-063
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

GID-063 adds opt-in pre-battle wagers: the player accepts a handicap in exchange for multiplied rewards. This task builds the foundation — the data-driven gambit catalogue, the pre-battle picker overlay inserted into the engagement flow, the application of each handicap to the battle state, and the in-battle badge. TID-225 then layers the reward multipliers and tests on top.

Design (from goal):
- Gambit catalogue (data-driven const table in `game_logic/battle/`): "Wounded Pride" — start at 25 HP (reward ×1.5); "Slow Start" — skip your first draw (×1.5); "Emboldened Foe" — enemy minions +1 ATK (×2); "Iron Veil" — enemy hero starts with 5 armor (×2). Exact numbers tuned in Plan phase.
- Pre-battle picker: when an enemy is engaged, a small overlay offers the gambits (mobile-friendly buttons per CLAUDE.md UI sizing rules — viewport-relative, never fixed pixels); "No Gambit" proceeds normally. Must not slow down players who never use it (one tap to skip, or auto-skip option).
- Active gambit shown as a badge in BattleScene during the fight.
- On victory, coin reward and drop-rarity roll are multiplied/boosted per the gambit (TID-225); on loss, normal loss flow.

## Research Notes

### Battle entry flow — there is NO pre-battle confirmation today; battle starts instantly on contact

1. `scenes/world/WorldScene.gd` line 1177–1180: on interact, `_find_nearby_enemy(px, pz, IsoConst.INTERACT_RANGE)` → `enemy.engage()`. (`IsoConst.AUTO_BATTLE_RANGE = 1.5` exists in `autoloads/IsoConst.gd` line 30 for proximity engagement.)
2. `scenes/world/entities/EnemyNPC.gd` `engage()` (lines 73–87): marks `_alive = false`, duplicates `enemy_data`, fills `enemy_deck` / `is_boss` / `boss_hp` / `phase2_deck` from `EnemyRegistry`, plays `enemy_engage` SFX, emits `GameBus.enemy_engaged.emit(edata)`, then `queue_free()`.
3. `autoloads/GameBus.gd` line 4: `signal enemy_engaged(enemy_data: Dictionary)`.
4. `autoloads/SceneManager.gd` `_on_enemy_engaged(enemy_data)` (lines 226–244): guards `_state != State.WORLD` and deck-size (`IsoConst.DECK_MIN`), then **immediately**: `save_manager.set_pending_battle(enemy_data)` → `save_manager.save()` → detaches the world scene from the tree (`_saved_world_scene`) → instantiates `_battle_scene_packed`, sets `_battle_overlay.enemy_data = enemy_data`, makes it the current scene, `_state = State.BATTLE`. No confirmation step exists anywhere in this chain.

**Recommended hook point:** split `SceneManager._on_enemy_engaged()` into (a) guards + picker display and (b) a new `_start_battle(enemy_data: Dictionary)` containing everything from `set_pending_battle` onward. Show the picker overlay (a `CanvasLayer` added to `get_tree().root`, like the tutorial popup pattern at SceneManager lines 417–432) while the world is still the current scene; on selection, write `enemy_data["gambit_id"] = chosen` and call `_start_battle(enemy_data)`. Caveat: `EnemyNPC.engage()` has already marked the enemy dead and `queue_free()`d itself, so the picker must not offer "cancel the fight" — only gambit choice vs no gambit (acceptable per design: one tap proceeds).

**Resume path must skip the picker:** `scenes/world/WorldScene.gd` lines 238–239 re-emits `GameBus.enemy_engaged.emit.call_deferred(SceneManager.save_manager.pending_battle_enemy_data)` when a pending battle exists. Detect resume via `not SceneManager.save_manager.pending_battle_state.is_empty()` (mid-battle snapshot) or via the `gambit_id` key already present in `pending_battle_enemy_data`, and go straight to `_start_battle()`.

### Where each handicap is applied — BattleScene._ready battle setup

`scenes/battle/BattleScene.gd` `_ready()` fresh-battle branch (lines 113–151):
- Line 114: `_state = GameState.new()` (constructor in `game_logic/battle/GameState.gd` builds two `PlayerState`s and draws opening hands of 4 — but BattleScene rebuilds decks after).
- Line 124: `_state.players[0].build_deck(player_deck)`; lines 125–126 `_apply_equipment_effects` / `_apply_passive_skills`; line 127 `draw_opening_hand(4)`.
- Lines 137–141: enemy `build_deck(enemy_deck, _enemy_tier)` (stat scaling via `CardDropUtil.enemy_card_stats` inside `PlayerState.build_deck`, `game_logic/battle/PlayerState.gd` lines 26–42).
- Lines 144–149: boss HP override sets `_state.players[1].hero.health/max_health` — same pattern Wounded Pride should use for the player hero.
- Line 151: `_state.players[0].start_turn(1)` — `PlayerState.start_turn()` (PlayerState.gd lines 84–87) calls `hero.gain_mana_for_turn`, `board.start_turn()`, then `draw_card()`. **This is the player's first draw** that "Slow Start" skips (the opening hand of 4 at line 127 stays).
- Restored-battle branch (lines 110–112) loads `GameState.from_dict(...)` — handicaps must NOT be re-applied there (they're already baked into the serialized state).

Per-handicap application:
- **Wounded Pride (25 HP):** after line 124, set `_state.players[0].hero.health = 25` (`HeroState.health/max_health` default 30, `game_logic/battle/HeroState.gd` lines 5–6). Whether `max_health` also drops to 25 is a Plan decision (affects heal caps).
- **Slow Start (skip first draw):** cleanest is a `skip_next_draw: bool` field on `PlayerState`, consumed at the top of `start_turn()` before `draw_card()`; add it to `PlayerState.to_dict()/from_dict()` (lines 89–137) for save-safety even though the turn-1 draw happens inside `_ready()` before any save can occur. Alternative: a one-shot flag set by BattleScene before line 151.
- **Emboldened Foe (enemy minions +1 ATK):** after line 140, iterate `_state.players[1].draw_deck` and bump `card.attack` for `card_class == "minion"` (cards already drawn into hand at line 141 — apply the buff BEFORE `draw_opening_hand(4)`, or iterate deck+hand). Must also cover the boss phase-2 rebuild: `_state.players[1].build_deck(p2_deck, p2_tier)` at BattleScene.gd line 1423. Cleanest option: a `minion_attack_bonus: int` on `PlayerState` applied inside `build_deck()` (serialize it too).
- **Iron Veil (enemy hero 5 armor):** `_state.players[1].hero.apply_status("armor", 5)` — the `armor` status is already consumed by `HeroState.take_damage()` (HeroState.gd lines 21–33) and serialized via `status_effects` in `to_dict()`. Zero new mechanics needed.

### Persisting the active gambit

- `SceneManager._on_enemy_engaged` already calls `save_manager.set_pending_battle(enemy_data)` (line 234), and `_on_battle_won` reads `save_manager.pending_battle_enemy_data` (lines 258–259) before `clear_pending_battle()` (line 303). Storing `gambit_id` as a key inside `enemy_data` therefore: (a) reaches BattleScene via `_battle_overlay.enemy_data = enemy_data` (line 241), (b) survives mid-battle save/resume (WorldScene line 239 re-emits the same dict), and (c) is readable by TID-225's reward code in `_on_battle_won` with no new SaveManager fields.
- Mid-battle state serialization: `GameState.to_dict()/from_dict()` (GameState.gd lines 53–71) already round-trips hero HP, status effects, and card attack values, so applied handicaps survive resume automatically. Only new `PlayerState` fields (e.g. `skip_next_draw`, `minion_attack_bonus`) need adding to its `to_dict()/from_dict()`.

### Gambit catalogue file conventions

- Location: `game_logic/battle/Gambits.gd`, sibling to `Keywords.gd` (which is a const-only file with no `class_name`). Per CLAUDE.md, callers must `const Gambits = preload("res://game_logic/battle/Gambits.gd")` — never rely on `class_name` scan. Plain `.gd` files manage their own UID, but this repo carries `.gd.uid` sidecars for most scripts (e.g. `GameState.gd.uid`) — create one to match (CI `--editor --quit` pass also backfills).
- Suggested shape: `const ALL: Dictionary = { "wounded_pride": { "name": "Wounded Pride", "desc": "...", "multiplier": 1.5, ... }, ... }` plus static helpers `get_gambit(id)` / `get_multiplier(id)` returning safe defaults (`1.0` for unknown/empty id). Mind the CLAUDE.md Variant-inference rules: annotate types when indexing dictionaries.

### Picker overlay UI conventions

- Pattern to copy: `CardInspectOverlay` (`scenes/battle/CardInspectOverlay.gd`) — full-screen dim backdrop, centered panel, close affordances. Also `SceneManager._on_tutorial_popup_requested` (lines 417–432) shows how SceneManager itself spawns a `CanvasLayer` (layer 999) + Control overlay on `get_tree().root` and frees it on a `closed` signal.
- CLAUDE.md UI sizing is mandatory: buttons `Vector2(vh * 0.12.., vh * 0.05..)` from `get_viewport().get_visible_rect().size.y`; font ~2–2.5% vh; never fixed pixels. Buttons are inherently touch-friendly (mobile/desktop parity rule — no keyboard-only path; Escape may additionally map to "No Gambit" on desktop).
- Auto-skip option: persist via `save_manager.get_setting("auto_skip_gambits", false)` / `set_setting` (the settings pattern used by `_apply_audio_settings`, SceneManager lines 137–141); a small CheckBox on the picker itself ("Don't ask again") is the lightest UX.
- New scene file(s): suggest a script-built overlay `scenes/battle/GambitPickerOverlay.gd` (no `.tscn` needed if built in code, like `TutorialPopup`); expose `signal gambit_chosen(gambit_id: String)` (empty string = no gambit).

### In-battle badge

- BattleScene already composes its side panel in code — `_add_pause_button()` / `_add_hero_power_button()` are called in `_ready()` (lines 156–157). Add an `_add_gambit_badge()` alongside: a small colored `Label`/`PanelContainer` reading `enemy_data.get("gambit_id", "")`, resolved to display name via the Gambits table, hidden when empty. Keyword-badge styling precedent: `_update_keyword_badges` uses ~1.8% vh font (docs/agent/battle-system.md lines 99–105).

### Constraints

- Do not break the deck-size guard or the `"mana"` tutorial emission order in `_on_enemy_engaged` (lines 229–233).
- `EnemyNPC` is already freed when the picker shows — picker cannot cancel the battle.
- Mimic chests (`GID-057`), siege (`GID-054`), and rival (`GID-053`) flows emit `enemy_engaged` directly with synthetic dicts — the picker will appear for those too, which is acceptable; the resume-skip check must rely on `pending_battle_state`, not on dict shape.
- Docs to update after Build: `docs/agent/battle-system.md`, `docs/agent/ui-and-scene-management.md` (scene-flow diagram lists `WORLD → BATTLE (enemy_engaged signal)` at line 26).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
