# TID-263: Extract card & hero view builders

**Goal:** GID-071
**Type:** agent
**Status:** pending
**Depends On:** TID-262

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Approximately 275 lines of card-panel and hero-panel construction/styling logic are embedded in BattleScene. This includes card rendering (zone refresh, view updates, ability text, card styling), hero rendering (status and targetability), and input binding. This task extracts the pure view-building logic (no input handlers) into a dedicated module, unifies duplicated card stats formatting, and consolidates board refresh logic.

## Research Notes

**Card rendering cluster:** BattleScene.gd:757–938 (~181 lines):
- _refresh_zone (766–778): Iterates card zone and updates each card view.
- _update_card_view (780–818): Refreshes card display (name, cost, mana, ability text, appearance).
- _get_card_ability_text/_get_card_ability_color/_build_card_vbox (820–872): Builds ability text labels with color coding.
- _apply_card_style (874–907): Sets modulate, scale, position, shader effects based on targetability state.
- _bind_card_input/_make_card_view (909–938): Creates the Control node and wires input signals.

**Hero rendering:** _refresh_hero (940–1030, ~91 lines):
- Heavy targetability styling (compare active hero vs opponent hero).
- Status display via _update_status (1032–1036).
- Self-only stat updates (hand size, mana, HP).

**Card stats duplication:** Stats text is built identically in _build_card_vbox (844–846) and _update_card_view (793–795):
- Spells: `"(%d)" % cost`
- Units: `"%d/%d  (%d)"` (attack/health/cost)

Extract _format_card_stats(card) helper.

**Board refresh identical logic:** Player and enemy board refresh at lines 759–760 differ only in view/zone_id — should be unified into a loop or parameterized function.

**Suggested new file:** scenes/battle/CardViewBuilder.gd. Owns _refresh_zone, _update_card_view, _get_card_ability_text, _apply_card_style, _refresh_hero, _build_card_vbox, and _format_card_stats. Input binding (_bind_card_input, _make_card_view) stays in BattleScene (BattleScene owns the input handlers and the event flow). Preload, don't rely on class_name.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
