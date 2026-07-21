# TID-462: Failed-Tap Marker Feedback

**Goal:** GID-122
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

`_handle_tap_to_move()` (WorldScene.gd:6407) shows only a text tip
(`_show_tip("Can't go there")` / `_show_tip("Can't reach that tile")`) when a
tap resolves to a wall tile or an unreachable tile. The text tip label sits
in a fixed HUD position, disconnected from where the player actually tapped,
so on a fast-paced screen it's easy to miss. A brief marker at the tapped
tile itself is a faster, more legible, non-verbal rejection signal — mirrors
the existing green destination marker's role but color-coded red and
transient instead of persistent.

## Plan

1. Add `_make_reject_marker() -> Node3D` alongside the existing
   `_make_dest_marker()` — same `TorusMesh` shape, red/orange
   `StandardMaterial3D` (`Color(1.0, 0.25, 0.2)`, unshaded, emissive) instead
   of green.
2. Add `_show_reject_marker(tile: Vector2i) -> void`: places the marker at
   the tile center (same formula as `_place_dest_marker`), fades/scales it
   out over ~0.4s via a one-shot `Tween` (scale to 1.4 + alpha to 0, then
   `queue_free()`), independent of `_dest_marker`/`_dest_tween` so it never
   fights the real destination-marker lifecycle.
3. Call `_show_reject_marker(tile)` from both rejection branches in
   `_handle_tap_to_move()`, in addition to the existing `_show_tip(...)` calls
   (kept for players who don't see the 3D marker, e.g. very fast taps).

## Changes Made

- `scenes/world/WorldScene.gd`: `_make_reject_marker()`,
  `_show_reject_marker(tile)`, wired into both rejection branches of
  `_handle_tap_to_move()`.

## Documentation Updates

- `docs/agent/tap-to-move.md`: note the reject marker alongside the existing
  destination-marker description.
