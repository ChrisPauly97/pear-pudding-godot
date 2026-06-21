# TID-263: Extract card & hero view builders

**Goal:** GID-071
**Type:** agent
**Status:** done
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

Create `scenes/battle/CardViewBuilder.gd` (extends RefCounted) that owns all pure view-building logic. BattleScene keeps input binding and orchestration.

**Functions moved to CardViewBuilder:**
- `_refresh_zone` → `refresh_zone(zone_node, cards, zone_id)` — calls `_make_card_view_fn` Callable stored at setup
- `_refresh_board_zone` → `refresh_board_zone(zone_node, zone_state, zone_id)` — calls `_on_empty_slot_fn` Callable stored at setup
- `_slot_size`, `_make_empty_slot_panel`, `_setup_empty_slot_panel`, `_apply_empty_slot_style`, `_apply_slot_enhancement_border`
- `_update_card_view` → calls `_bind_card_input_fn` Callable stored at setup
- `_get_card_ability_text`, `_get_card_ability_color`, `_build_card_vbox`, `_apply_card_style`
- `_update_keyword_badges`, `_refresh_hero`
- `_get_ward_valid_targets` (pure helper, no side effects)
- New helper: `format_card_stats(card, cost)` — eliminates duplicated stats text in `_build_card_vbox`/`_update_card_view`
- Constants: `_SPELL_EFFECT_LABELS`, `_EMERGENCE_LABELS` move to CardViewBuilder

**Stays in BattleScene:**
- `_bind_card_input` (connects to BattleScene input handlers)
- `_make_card_view` (refactored to delegate build/style to `_view`)
- `_trigger_dual_face_flip` (accesses `_flipped_dual_ids`)
- `_update_status`, `_refresh_all`

**CardViewBuilder API:**
- `setup(vh, fx, bind_card_input_fn, on_empty_slot_fn, make_card_view_fn)`
- `set_battle_state(state, enemy_data)`
- `update_context(targeting_active, targeting_friendly, dragged_card, hand_drag_card, slot_targeting_spell, slot_select_card)`
- Public `refresh_zone`, `refresh_board_zone`, `refresh_hero`, `build_card_vbox`, `update_card_view`, `apply_card_style`, `get_ward_valid_targets`

**BattleScene changes:**
- Add `var _view: CardViewBuilder` field
- In `_ready`: create and setup `_view`; call `_view.set_battle_state` after `_state` is built
- `_refresh_all`: call `_view.update_context(...)` at start, then delegate all zone refreshes to `_view`
- `_make_card_view`: delegate to `_view.build_card_vbox` and `_view.apply_card_style`
- `_on_enemy_card_input`: call `_view.get_ward_valid_targets` instead of `_get_ward_valid_targets`
- Remove moved constants/functions

## Changes Made

- Created `scenes/battle/CardViewBuilder.gd` (~512 lines, extends RefCounted): owns all pure view-building logic extracted from BattleScene. Public API: `setup`, `set_battle_state`, `update_context`, `refresh_zone`, `refresh_board_zone`, `refresh_hero`, `build_card_vbox`, `update_card_view`, `apply_card_style`, `get_ward_valid_targets`. Public constants `SPELL_EFFECT_LABELS`, `EMERGENCE_LABELS`. New helper `format_card_stats(card, cost)` eliminates the stats-text duplication between `build_card_vbox` and `update_card_view`. Uses Callable fields (`_bind_card_input_fn`, `_on_empty_slot_fn`, `_make_card_view_fn`) to call back into BattleScene without a direct dependency.
- Modified `scenes/battle/BattleScene.gd` (reduced from ~3004 to ~2561 lines): added `const CardViewBuilder = preload(...)` and `var _view: CardViewBuilder`. `_ready()` creates and sets up `_view`. `_refresh_all()` and new `_refresh_player_board()` call `_view.update_context(...)` then delegate all zone/hero refreshes to `_view`. `_make_card_view()` now delegates to `_view.build_card_vbox` and `_view.apply_card_style`. `_on_enemy_card_input` uses `_view.get_ward_valid_targets(...)`. Removed all moved functions and constants.
- Updated `scenes/battle/CardInspectOverlay.gd`: updated comment to reference `CardViewBuilder.SPELL_EFFECT_LABELS` and `CardViewBuilder.EMERGENCE_LABELS`.

## Documentation Updates

- `docs/agent/battle-system.md`: Added new **CardViewBuilder** section under BattleScene UI documenting the full public API and ownership split. Updated all references that previously pointed to BattleScene private functions (`_update_keyword_badges`, `_apply_card_style`, `_get_ward_valid_targets`, `_refresh_hero`, `_refresh_board_zone`, `_SPELL_EFFECT_LABELS`) to point to their new homes in CardViewBuilder.
