# TID-234: Battle UI performance & enemy hand concealment

**Goal:** GID-064
**Type:** agent
**Status:** done
**Depends On:** TID-232

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The battle UI churns nodes/connections on every action and leaks the AI's hidden
information. Depends on TID-232 since the refresh paths being touched are also where
rules fixes land.

## Research Notes

1. **Enemy hand rendered face-up (medium, gameplay-affecting).**
   `scenes/battle/BattleScene.gd:754, 905-918`: the enemy hand uses the same face-up
   card view as the player's (name, stats, ability text) and the right-click/long-press
   inspect binding applies to it. Fix: render card backs for `zone_id == "enemy_hand"`
   and skip the inspect binding there.

2. **_refresh_all node churn (medium).** `BattleScene.gd:905-925, 870-903`: every
   `_refresh_all()` (after every single action) disconnects/reconnects 2-3 `gui_input`
   lambdas per card, frees and re-instantiates a LongPressDetector node per card,
   allocates a fresh StyleBoxFlat per card, and calls `CardRegistry.get_template()`
   (builds a new Dictionary, CardData.gd:25-43) per card just for its color. Mid-game:
   ~20 nodes churned + ~60 connect/disconnects per click on Android. Fix: bind input and
   create the detector once in `_make_card_view`; cache style/color on the panel and
   mutate only `bg_color`/borders on refresh.

3. **Panel reuse of dying nodes (low).** `BattleScene.gd:762-774`: `_refresh_zone`
   reuses `get_children()`, which still contains panels `queue_free`d by an earlier
   refresh in the same frame; shrink-then-grow within one frame (e.g.
   `_on_turn_ended`'s double `_refresh_all`) can "reuse" a panel that vanishes at frame
   end. Fix: skip children with `is_queued_for_deletion()`.

4. **_process polling (low).** `BattleScene.gd:243-255`: `_process` polls
   `_tutorial_timer` and hand-animates the boss-banner alpha every frame for the whole
   battle. Fix: `get_tree().create_timer()` for the tutorial, Tween for the banner fade,
   drop `_process`.

5. **Float layer above overlays (cosmetic).** `BattleScene.gd:104-106` vs :1531/:1590:
   `_float_layer` is a CanvasLayer at layer 128, so damage numbers render on top of the
   victory/boss overlays (plain scene children). Fix: hide/clear the float layer when an
   overlay shows, or put overlays on a higher CanvasLayer.

6. **LongPressDetector behaviour (shared with TID-235 — coordinate, don't duplicate).**
   `scenes/ui/LongPressDetector.gd:13-18, 20`: `_process` permanently enabled and global
   `_input` per instance; holding an inner Button fires `long_pressed` AND the button's
   `pressed` on release. The detector script itself is fixed in TID-235; this task just
   adopts the fixed version for battle card views.

Drag-to-play being hand-rolled global `_input` (BattleScene.gd:329-421) is logged as
backlog BID-010 — do not rewrite it here.

Verification: play a full battle headless-windowed; assert no per-action node count
growth (`get_child_count` stable across refreshes), enemy hand shows backs, inspect
works on player cards only. Run full suite.

## Plan

1. In `_make_card_view`: detect `zone_id == "enemy_hand"` and render a face-down back (no stats/name visible); skip inspect binding for that zone.
2. In `_refresh_zone`: skip children with `is_queued_for_deletion()`.
3. Move input binding and LongPressDetector creation into `_make_card_view` (not refresh).
4. Cache StyleBoxFlat on the panel node as metadata; mutate only `bg_color` on refresh.
5. Replace `_process` tutorial/banner polling with `SceneTreeTimer` + `Tween`.
6. When victory/loss overlay shows: hide `_float_layer`.

## Changes Made

- `scenes/battle/BattleScene.gd`:
  - `_make_card_view`: for `zone_id == "enemy_hand"`, returns a dark-purple card back panel (no text, no input); for other zones, creates StyleBoxFlat once and stores as `set_meta("card_style", ...)` to avoid per-refresh allocation.
  - `_update_card_view`: skips update when `panel.get_meta("is_card_back")` is true.
  - `_apply_card_style`: retrieves cached StyleBoxFlat, resets borders, mutates in place — no new allocation per refresh.
  - `_bind_card_input`: skips right-click inspect and LongPressDetector for enemy_hand; reuses existing LPD node (by name `"_lpd"`) instead of queue_free + new.
  - `_refresh_zone`: filters `get_children()` to exclude `is_queued_for_deletion()` nodes.
  - Removed `_process` entirely; removed `_tutorial_timer` and `_boss_banner_timer` vars.
  - `_show_battle_tutorial`: uses `get_tree().create_timer(TUTORIAL_DURATION, false).timeout` signal.
  - `_show_boss_banner` / `_check_boss_phase2`: extracted `_start_banner_fade(banner)` that creates a Tween for the fade-out.
  - `_show_pause_overlay` / `_hide_pause_overlay`: hide/show `_float_layer`.
  - `_show_victory_overlay`, `_show_victory_overlay_boss`, `_show_duel_victory_overlay`, `_show_duel_loss_overlay`: hide `_float_layer` at top.

## Documentation Updates

Performance improvements documented in `docs/agent/battle-system.md` (TID-285 pattern).
