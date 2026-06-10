# TID-216: Battle hooks: attribute kills/survival to collection instances post-battle

**Goal:** GID-060
**Type:** agent
**Status:** pending
**Depends On:** TID-215

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The emotional core of GID-060: a card that fights remembers. After each battle, kills made by each of the player's deck cards and their survival must be written back to the matching `SaveManager.owned_cards` instance (fields added in TID-215), so ranks and titles accrue. The crux is mapping a battle `CardInstance` back to a collection entry — **that mapping does not exist today** and must be created by this task.

## Research Notes

**The crux, verified honestly: collection UIDs do NOT survive into battle.**
- `/home/user/pear-pudding-godot/scenes/battle/BattleScene.gd` `_ready()` lines 116–124: player deck is built via `SceneManager.save_manager.get_deck_template_ids()` → `_state.players[0].build_deck(player_deck)`. Template ID **strings only**; instance UIDs are stripped before the battle engine sees them.
- `/home/user/pear-pudding-godot/game_logic/battle/PlayerState.gd` `build_deck(card_ids: Array[String], difficulty_tier: int = 0)` (line 26): for each id it fetches `CardRegistry.get_template(cid)` and creates `CardInstance.new(tmpl)`.
- `/home/user/pear-pudding-godot/game_logic/battle/CardInstance.gd`: `instance_id` (line 6) is generated in `_init` as `"%s_%d" % [tmpl.get("id"), _next_id]` from a static counter (lines 37–38) — it is a per-battle runtime id with **no relationship** to the collection `uid`.
- `SaveManager.get_deck_instances() -> Array[Dictionary]` (autoloads/SaveManager.gd line 613) returns the deck's instance dicts but **has zero callers** in the codebase (verified by grep).
- Corollary gap: the player's per-instance rolled stats (`attack`/`health`/`cost` in the instance dict) are never applied in battle either — `build_deck` uses template base stats (tier scaling only applies to the **enemy** deck via `CardDropUtil.enemy_card_stats`, PlayerState.gd lines 36–40). Threading instances into battle fixes both problems at once.

**Proposed mapping (decide details in Plan):** add `collection_uid: String = ""` to `CardInstance`; add a build path that consumes `SaveManager.get_deck_instances()` (e.g. `PlayerState.build_deck_from_instances(insts: Array[Dictionary])`) setting `collection_uid`, instance attack/health/cost, and TID-215 rank bumps. Enemy cards keep `collection_uid == ""` and are excluded from attribution.

**Where kills happen (all sites that remove a dead minion):**
- Player minion attacks enemy minion: `BattleScene._on_enemy_card_input` lines 1112–1122 — `target.take_damage(attacker.attack)`; if `not target.is_alive()` → kill credit to `attacker`. Counterattack: `attacker.take_damage(target.attack)` may kill the player's own card (survival-relevant, not a kill).
- Player minion attacks enemy hero: `_on_enemy_hero_input` lines 1150–1157 (no minion kill; hero damage only).
- AI turn: `/home/user/pear-pudding-godot/ai/BasicAI.gd` `decide_turn()` — attack Callables at lines 43–54: `tgt` is the **player's** minion; `if not tgt.is_alive()` (line 48) the player's card died (survival tracking); `if not mc.is_alive()` (line 51) the AI attacker died to the player's minion's counterattack → kill credit to `tgt` (the player's card). These run as deferred Callables, so attribution is cleanest inside `take_damage`/board-removal flow or by post-hoc scan, not by instrumenting each Callable from outside.
- Spells: `BattleScene._resolve_spell_effect` kill sites at lines ~1267–1372 (`deal_damage_single`, `deal_damage_all`, `deal_damage_random`, `destroy_low_hp`, `curse_minion`, `lifesteal_hit`) — spell kills are made by spell cards; Plan must decide whether spell cards earn kills (they are discarded after cast but still map to a collection instance via `collection_uid`).
- Hero power `active_damage_all`: `_use_hero_power` lines 524–527 (kills by the hero, not a card — likely unattributed).
- Status ticks (poison): processed at turn start in BattleScene — deaths there are not caused by a specific card; Plan should explicitly scope these out or attribute to the poison applier.
- `GameBus.card_attacked(attacker_id, target_id)` signal exists in `/home/user/pear-pudding-godot/autoloads/GameBus.gd` (line 17) but is **never emitted** — do not rely on it; either start emitting it or use a direct tally.

**Simplest robust design candidate (refine in Plan):** keep a per-battle tally on the battle `CardInstance` itself (e.g. `battle_kills: int`), incremented at each kill site; on victory, walk all zones (board, hand, draw_deck, discard) of `players[0]`, and for each card with `collection_uid != ""` write `kills += battle_kills` and `battles_survived += 1` (survival definition — "deck was in a won battle" vs "card not in discard at battle end" — decided in Plan) into `SaveManager.get_instance_by_uid(uid)` (returns the live dict, so direct mutation + `_dirty = true` works; prefer a proper `SaveManager` setter API).

**Where battles end and rewards are granted:**
- `BattleScene._check_game_over()` (line 1446): on win plays SFX, computes drop, shows victory overlay; the overlay's Collect button emits `GameBus.battle_won.emit({"card_reward": ..., "weapon_reward": ...})` (line 1526) or boss variant `{"card_rewards": [...], "weapon_reward": ...}` (line 1585). On loss: `GameBus.battle_lost.emit()` (line 1476).
- `/home/user/pear-pudding-godot/autoloads/SceneManager.gd` `_on_battle_won(result: Dictionary)` (line 253): all post-battle persistence happens here — `mark_enemy_defeated`, `increment_progress`, rarity roll + `add_card_instance` for rewards, coins, XP, then `clear_pending_battle()`/`clear_pending_battle_state()` and `_restore_world()`. Veterancy attribution can either ride the `battle_won` result dict (e.g. `result["veterancy"] = {uid: {"kills": n, "survived": true}}`) and be applied here, or be applied directly in BattleScene before emitting — Plan decides; SceneManager application matches the existing reward pattern.
- `_on_battle_lost()` (line 310): loss path — no veterancy writes (or Plan-phase decision).

**Mid-battle save/resume (GID-034) interaction:** `CardInstance.to_dict()` (line 115) / `from_dict()` (line 142) serialize the full battle state into `SaveManager.pending_battle_state`. New fields (`collection_uid`, per-battle kill tally) **must** be added to both, or attribution silently breaks on resume. `PlayerState.to_dict/from_dict` (PlayerState.gd, discard restore at line 132) need no change beyond what CardInstance carries.

**Tests:** `tests/unit/test_player_state.gd` shows how to test PlayerState without CardRegistry ("Tests bypass build_deck … by directly" constructing instances). `test_card_instance.gd` covers to_dict/from_dict round-trips — extend for new fields. Runner: `godot --headless --path . -s tests/runner.gd`.

**Constraints (CLAUDE.md):** preload scripts (`const VeterancyUtil = preload(...)`), explicit types for `Dictionary.get()` results, `assign()` when copying plain Arrays into typed arrays (BattleScene already does `enemy_deck.assign(enemy_data["enemy_deck"])` at line 139).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
