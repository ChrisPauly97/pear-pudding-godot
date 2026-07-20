# TID-463: Locked Cantrip Discoverability (BID-050)

**Goal:** GID-122
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

BID-050: `[G] Phase` / `[D] Dig` HUD buttons are registered with a
`visible_when` Callable bound directly to `CantripManager.is_available(...)`
(WorldHUD.gd:134-148), so a deck that doesn't qualify (starter deck has 3 of
4 required Ghost-family cards) renders no button at all — a hidden control
can't teach a player that Ghost Phase exists or that one more Ghost-family
card would unlock it. `CantripManager` (game_logic/world/CantripManager.gd)
has `is_available`, `get_threshold`, and a private `_count_family` — no public
way to get the current count for a progress readout.

Pressing an unlock-gated button while genuinely disabled (`Button.disabled =
true`) fires no `pressed` signal in Godot, so a truly `disabled` button
can't explain itself. `WorldScene._activate_ghost_phase()` /
`_activate_skeleton_dig()` already handle the "not available" case by
emitting a `GameBus.hud_message_requested` explainer — keeping the button
enabled (just visually dimmed) lets a curious tap reuse that existing
explainer with no new dispatch logic.

## Plan

1. `CantripManager.gd`: add `static func count_family(cantrip_id: String,
   template_ids: Array[String]) -> int` — thin public wrapper around the
   existing private `_get_family` + `_count_family`.
2. `WorldHUD._create_cantrip_buttons()`: register both buttons with
   `Callable()` for `visible_when` (always visible — the registry's
   visibility toggle is not the right tool for the "locked" state) and
   always set `.visible = true` once.
3. Add `_update_cantrip_button_state(btn: Button, cantrip_id: String,
   base_label: String) -> void`: computes `available`, `count`, `threshold`;
   sets `btn.text` to `base_label` when available or
   `"%s (%d/%d)" % [base_label, count, threshold]` when locked; sets
   `btn.modulate` to `Color(1,1,1,1)` (available) or `Color(1,1,1,0.5)`
   (locked). Button stays enabled either way so a locked tap still routes to
   the existing "requires N+ family cards" HUD message.
4. Call it once from `_create_cantrip_buttons()` for initial state and from
   `refresh_action_cluster()` (replacing the old `refresh_visibility(...)`
   calls for these two ids) so `GameBus.inventory_changed` keeps it live as
   the deck changes.

## Changes Made

- `game_logic/world/CantripManager.gd`: `count_family()` public static.
- `scenes/world/WorldHUD.gd`: cantrip buttons always visible; new
  `_update_cantrip_button_state()` drives dimmed/progress-labeled vs. full
  active state; `refresh_action_cluster()` updated.

## Documentation Updates

- `docs/agent/card-cantrips.md`: note the always-visible/progress-labeled
  button state, referencing BID-050.
- `tasks/backlog/BID-050--hidden-cantrip-undiscoverable.md` → moved to
  `tasks/archive/backlog/`, `tasks/index.md` updated (resolved by this task).
