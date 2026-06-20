# TID-219: Soulbind Victory Flow, Captured-Signature Save Tracking, Overlay UI

**Goal:** GID-061
**Type:** agent
**Status:** done
**Depends On:** TID-218

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Wires the TID-218 `CaptureTracker` verdict into the victory flow: a Soulbind ritual overlay offers the signature card when the condition was met and the signature is uncaptured; `SaveManager.captured_signatures` makes each capture one-time; repeat wins show condition status to support the hunt; signature cards are excluded from the shop and protected from sell/scrap/craft.

## Research Notes

### Victory flow today (`scenes/battle/BattleScene.gd`)

- `_check_game_over()` (line 1446): on winner 0 → `AudioManager.play_sfx("battle_win")` → `enemy_type = str(enemy_data.get("enemy_type", "undead_basic"))` (line 1452) → `EnemyRegistry.get_drop_pool(enemy_type)` → regular path picks one random card and calls `_show_victory_overlay(reward_card_id, "")` (line 1473); boss path collects weapon pool and calls `_show_victory_overlay_boss(pool, weapon_reward_id)` (line 1468).
- `_show_victory_overlay()` (line 1478): builds a full-rect `PanelContainer` overlay (bg `Color(0.05, 0.05, 0.1, 0.92)`), "Victory!" title at `_vh * 0.06`, reward label, Collect button (`_vh * 0.18` × `_vh * 0.06`); button `pressed` → `overlay.queue_free()` + `GameBus.battle_won.emit({"card_reward": final_card, "weapon_reward": final_weapon})` (line 1526). Boss variant at line 1533 emits `{"card_rewards": [...], "weapon_reward": ...}` (line 1585). Follow this exact UI style for the Soulbind overlay; all sizes viewport-relative per CLAUDE.md (`_vh` is already computed in BattleScene).
- Soulbind hook: in `_check_game_over()` winner-0 path, query the TID-218 tracker + `EnemyRegistry.get_signature_card(enemy_type)` + `SaveManager.captured_signatures`. Three outcomes:
  1. Signature exists, uncaptured, condition satisfied → show Soulbind ritual overlay (distinct styling, e.g. violet accent) offering the signature card **in addition to** the normal reward; emitted `battle_won` payload carries an extra key, e.g. `"signature_capture": "<card_id>"`.
  2. Signature exists, uncaptured, condition NOT satisfied → normal victory overlay plus a condition-status line, e.g. `"Soulbind: <condition text> — not met"`, sourced from `CaptureTracker.condition_text()`.
  3. No signature or already captured → current behavior unchanged.
- Decline path: if the player can decline the ritual (design decision for Plan: simplest is auto-grant with a "Soulbound!" celebration; if declining is kept, declining must NOT mark it captured), normal rewards are unaffected either way.

### Reward granting (`autoloads/SceneManager.gd`)

- `GameBus.battle_won` → `_on_battle_won(result)` (line 253). Reads `enemy_type` from `save_manager.pending_battle_enemy_data` (line 258), marks defeat, grants `result["card_reward"]` via `CardDropUtil.effective_rarity/roll_stats` + `save_manager.add_card_instance(id, rarity, atk, hp, cost)` (line 275; signature at SaveManager.gd line 513), handles boss `card_rewards` list (lines 281–288), then coins.
- Add handling for `result.get("signature_capture", "")`: call `save_manager.add_card_instance(sig_id, "legendary", ...)` (or a fixed rarity decided in Plan — `CardDropUtil.roll_stats` keys off rarity) AND `save_manager.mark_signature_captured(sig_id)`. Granting in SceneManager (not BattleScene) matches every other reward.

### SaveManager (`autoloads/SaveManager.gd`)

- Add `var captured_signatures: Array[String] = []` near the other id-lists (`defeated_enemies` line 33, `collected_scrolls` line 52, `owned_weapons` line 58). Methods following `mark_scroll_collected()` (line 684) / `add_weapon()` (line 693) pattern: `mark_signature_captured(card_id)` (append-if-absent + dirty), `is_signature_captured(card_id) -> bool`.
- Persistence: add to the save dict (~line 427 block) and load with `captured_signatures.assign(data.get("captured_signatures", []))` (~line 373 block; `owned_weapons` at line 386 is the pattern). Reset in the new-game reset block (~line 151).
- Migration: `CURRENT_SAVE_VERSION` is 14 (line 184); migrations `_migrate_vN_to_vN+1` at lines 188–318 backfill missing fields. Add v14→v15 backfilling `captured_signatures: []`. **Coordination:** pending GID-045 (TID-170) also plans a v15 migration for `bestiary` — whichever lands first takes 15; rebase the other to 16.

### Shop / economy exclusivity

- `scenes/ui/ShopScene.gd` lines 99–106: lists **every** `CardRegistry.get_all_ids()` card filtered only by `CardRegistry.is_unlocked()` (legendary-achievement gating, `autoloads/CardRegistry.gd` line 108). Signature cards must be skipped — cleanest: `if EnemyRegistry.get_all_signature_card_ids().has(id): continue` (accessor from TID-218), or a `CardData` flag (see below).
- Sell/scrap: `scenes/ui/InventoryScene.gd` line 394 hides the sell/scrap row when `bool(tmpl.get("is_unique", false))`. **Gotcha:** `CardData.is_unique` (data/CardData.gd line 21) is NOT included in `to_template_dict()` (lines 25–43), so that check currently always sees `false` for registry templates — add `"is_unique": is_unique` (and `"can_craft": can_craft` if needed) to `to_template_dict()` as part of making signature cards unsellable.
- Crafting: `CardRegistry.is_craftable()` (line 99) already excludes `can_craft = false` cards — signature cards set `can_craft = false` in their `.tres` (TID-220).
- Drop pools: exclusivity also means TID-220 must not list signature ids in any `drop_pool`; no code needed.

### Repeat-win hunt support

- "Already captured" check uses `SceneManager.save_manager.captured_signatures` — BattleScene accesses SaveManager as `SceneManager.save_manager` (e.g. line 1461).
- Condition-status line on failed attempts needs human-readable text per condition key — keep a single source (`CaptureTracker.condition_text()` from TID-218), mirroring how `_SPELL_EFFECT_LABELS` is maintained in BattleScene (line ~1258 area) per `docs/agent/battle-system.md`.

### Tests

- Extend headless tests (`godot --headless --path . -s tests/runner.gd`): SaveManager round-trip + migration for `captured_signatures`; `mark_signature_captured` idempotency; `to_template_dict()` now exposing `is_unique`; shop-exclusion predicate returns true for signature ids. UI overlay itself is not headless-testable — verify via the result-dict contract (`signature_capture` key handling in a SceneManager-level test if feasible).

## Plan

Implemented alongside TID-218 and TID-220:
1. Add `SaveManager.captured_signatures` field, `mark_signature_captured` / `is_signature_captured` methods, save/load/new-game/migration.
2. Update `_check_game_over` winner-0 path with three-outcome dispatch.
3. Update `_show_victory_overlay` signature to accept optional hunt-status params.
4. Add `_show_soulbind_overlay` for the capture path (violet accent, extra sig card display).
5. Update `SceneManager._on_battle_won` to handle `signature_capture` key.
6. Exclude signatures from ShopScene via `EnemyRegistry.get_all_signature_card_ids()`.
7. Fix `CardData.to_template_dict()` to expose `is_unique` and `can_craft` so InventoryScene sell/scrap guard works.

## Changes Made

- `autoloads/SaveManager.gd`: Added `captured_signatures: Array[String]`, `mark_signature_captured`, `is_signature_captured`; persisted in save dict; loaded; reset in `new_game()`; v34→v35 migration backfills empty array; `CURRENT_SAVE_VERSION` bumped to 35.
- `scenes/battle/BattleScene.gd`: `_check_game_over` winner-0 path dispatches to `_show_soulbind_overlay` (condition met + uncaptured), `_show_victory_overlay` with hunt-status (uncaptured + not met), or plain `_show_victory_overlay` (no signature / already captured). `_show_victory_overlay` now accepts optional `sig_card_id`, `condition_text_arg`, `condition_met` params. Added `_show_soulbind_overlay` emitting `battle_won` with `"signature_capture": sig_id`.
- `autoloads/SceneManager.gd`: `_on_battle_won` handles `result.get("signature_capture", "")` — rolls stats, calls `add_card_instance` + `mark_signature_captured`.
- `scenes/ui/ShopScene.gd`: Added `const EnemyRegistry` preload; filters out signature card IDs from shop listings.
- `data/CardData.gd`: `to_template_dict()` now includes `"is_unique": is_unique` and `"can_craft": can_craft`.

## Documentation Updates

- Covered in `docs/agent/soulbinding.md` (created as part of this task group).
