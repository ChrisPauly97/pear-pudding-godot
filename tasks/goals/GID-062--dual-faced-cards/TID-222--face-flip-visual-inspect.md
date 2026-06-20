# TID-222: UI: face-flip visual, inspect overlay shows both faces

**Goal:** GID-062
**Type:** agent
**Status:** done
**Depends On:** TID-221

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-221 gives dual-faced cards a resolved Light/Dark face at battle start. This task
makes that visible: a flip animation when a dual-faced card is first shown in the hand,
a `CardInspectOverlay` that shows BOTH faces (so players can plan around a future
alignment change), and a collection/inventory view that shows the alignment-matching
face plus a clear "dual-faced" indicator.

## Research Notes

### Battle card faces — where cards are rendered

All in `scenes/battle/BattleScene.gd`:

- `_refresh_zone(zone_node, cards, zone_id)` (line 762) — reuses existing
  `PanelContainer` children via `_update_card_view()` (line 776) or creates new ones via
  `_make_card_view(card, zone_id)` (line 927). Zone ids: `"hand"`, `"board"`,
  `"enemy_board"`. IMPORTANT: zones are refreshed constantly (`_refresh_all()` after
  every state change), so a "first shown" flip must be guarded — track flipped
  `card.instance_id`s in a `Dictionary`/set on BattleScene, keyed per battle.
- `_build_card_vbox(card, with_status_row)` (line 830) — builds NameLabel, StatsLabel
  (spells: `"(%d)" % cost`; minions: `"%d/%d  (%d)"`), DescLabel (ability text via
  `_get_card_ability_text()` line 816, colored by `_get_card_ability_color()` line 825 —
  amber for emergence, green for spells), KeywordRow badges, optional StatusRow.
- `_update_card_view()` (line 776) refreshes those same named children in place.
- `_apply_card_style(panel, card, zone_id)` (line 870) — StyleBoxFlat with
  `tmpl.get("color")` from `CardRegistry.get_template(card.template_id)`; this is where
  a Light/Dark face tint or border could live.
- `_bind_card_input()` (line 905) — right-click and `LongPressDetector` long-press both
  call `_show_card_inspect(card)` (line 462). Card size: `Vector2(_vh * 0.10, _vh * 0.19)`.

### Flip animation building blocks

BattleScene already uses tweens on card panels: `_flash_node(node, color)` (TID-078)
tweens `modulate`; `_trigger_shake()` tweens position. A standard 2D flip is two chained
tweens on the panel: `scale.x` 1→0 (with `pivot_offset.x = size.x * 0.5`), swap/reveal
content at the midpoint, then `scale.x` 0→1. Hand is dealt in `_ready()`
(`draw_opening_hand(4)`, line 127) and on turn start; first render after `_ready()` runs
through `_refresh_all()` (line 160), so triggering the flip in
`_make_card_view`/`_update_card_view` when a dual card's instance_id is unseen covers
both deal and later draws. TID-221 decides how the UI detects "dual-faced + active face"
on a `CardInstance` (e.g. `dual_card_id`/`active_face` fields) — use that, do not
re-derive alignment in the UI.

### CardInspectOverlay — show both faces

`scenes/battle/CardInspectOverlay.gd` (no `.tscn`; pure code-built Control):

- Entry: `show_card(card: CardInstance)` → `_build_ui()`. Backdrop tap, Close button,
  and Escape all `_close()` (emits `closed`, `queue_free()`).
- Current layout: single centered panel `vp.x * 0.6` × `_vh * 0.62` containing color bar
  (from `CardRegistry.get_template(_card.template_id)["color"]`), name, class/magic-type
  row (reads `magic_type`/`magic_branch` from the template, lines 113–129), stats,
  description, spell-effect plain English (`_SPELL_EFFECT_LABELS`, lines 10–25 — MUST
  stay in sync with `BattleScene._SPELL_EFFECT_LABELS`, per TID-140), keyword
  descriptions, emergence text (`_EMERGENCE_LABELS`, lines 27–33), status effects.
- For both faces: either a second panel side-by-side (`vp.x * 0.42` each) or a stacked
  section per face; refactor the per-face body (name/stats/desc/effect/keywords) into a
  helper taking a template Dictionary so Light and Dark faces render through one code
  path. Mark the ACTIVE face (border highlight or "Active" tag) using the resolved face
  info from TID-221. Inspect is also reachable for enemy/board cards — both-faces view
  should appear wherever the inspected card is dual-faced.
- Instantiated by `BattleScene._show_card_inspect(card)` (line 462) — check whether the
  call site needs extra context (e.g. the dual shell id) or whether `CardInstance`
  carries enough after TID-221.

### Collection / inventory indicator

`scenes/ui/InventoryScene.gd` (preloads CardRegistry at line 5):

- Card rows resolve templates via `CardRegistry.get_template(tid)` (lines 333, 457, 535,
  670); sorting at line 268; rarity colors/tags at lines 305/313 — the `"[L]"` legendary
  tag pattern (line 313) is the precedent for a compact dual-faced marker (e.g. `"[◑]"`
  or `"Dual"` chip).
- Show the face matching CURRENT alignment: compare
  `SceneManager.save_manager.corruption_points` vs `redemption_points` (the same helper
  TID-221 adds — reuse it, don't duplicate the comparison or tie rule).
- `ShopScene.gd` `_make_card_row(id, tmpl, coins)` (used at line 105) shows whatever
  template it is given — if the dual shell id is what's sold/collected, shop rows should
  also show the alignment face (verify with the model chosen in TID-221).

### Mobile parity + sizing (CLAUDE.md)

- Inspect already covers desktop (right-click) and mobile (long-press / tap-without-drag
  tracked by `_drag_moved`); the both-faces panel must fit and remain readable on a
  phone viewport — size everything from `get_viewport().get_visible_rect().size`
  fractions like the existing overlay (`_vh * 0.038` name font etc.). No fixed pixels.
- Flip must not depend on hover — it is a passive animation, fine for touch.

### Constraints

- Don't break `_refresh_zone`'s panel reuse: the flip tween manipulates `scale`/`pivot`
  on panels that may be freed by a later refresh — kill tweens on freed panels or guard
  with `is_instance_valid`.
- Pause system (`get_tree().paused`) stops tweens of non-ALWAYS nodes — acceptable for
  the flip; do not mark card panels `process_mode = ALWAYS`.
- Tests: `godot --headless --path . -s tests/runner.gd`. UI is hard to unit-test; keep
  face-selection logic in TID-221's testable helper and keep this task's logic thin.
- Update `docs/agent/battle-system.md` (Card Inspect Overlay + BattleScene UI sections)
  and `docs/agent/inventory-and-deck.md` for the collection indicator.

## Plan

Implemented during TID-221/222/223 combined build:
- BattleScene: track flipped card ids in `_flipped_dual_ids`; trigger `_trigger_dual_face_flip(panel)` on first hand reveal of any dual card.
- CardInspectOverlay: full rewrite with `_build_dual_face_ui()` / `_build_face_panel()` / `_build_face_body()` helpers; side-by-side Light/Dark panels with green active border.
- InventoryScene: `◑` badge on all 4 card-row builders for dual cards; templates resolved via `get_template_for_face`.

## Changes Made

- `scenes/battle/BattleScene.gd`: added `_flipped_dual_ids: Dictionary`; flip trigger in `_make_card_view()`; `_trigger_dual_face_flip(panel)` (scale.x tween 0.01→1.0, 0.28s TRANS_BACK EASE_OUT).
- `scenes/battle/CardInspectOverlay.gd`: complete rewrite adding `_build_dual_face_ui()`, `_build_face_panel()`, and `_build_face_body(container, tmpl, card, show_status)` — shared content builder for single and dual paths; active face highlighted with green border.
- `scenes/ui/InventoryScene.gd`: all 4 card-row builders updated to use `get_template_for_face` and add `◑` badge for dual cards.

## Documentation Updates

- `docs/agent/battle-system.md`: flip animation and CardInspectOverlay dual-face layout documented in the Dual-Faced Corruption Cards section.
- `docs/agent/inventory-and-deck.md`: added "Dual-Faced Card Indicator" section.
