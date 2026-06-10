# TID-234: Battle UI performance & enemy hand concealment

**Goal:** GID-064
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
