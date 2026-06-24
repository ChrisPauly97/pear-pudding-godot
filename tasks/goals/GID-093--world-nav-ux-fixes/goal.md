# GID-093: World Navigation & UX Fixes

## Objective

Fix three friction points in everyday play: the combined menu can't be closed (its X is
hidden behind the minimap), there's no way back to town from the infinite overworld without
a waystone, and tap-to-move can't be steered once your finger is down.

## Context

These are UX bugs reported alongside the co-op fixes (GID-092) but independent of
multiplayer:

1. The unified menu hub (GID-081) renders **behind** the HUD, and its Close button sits in
   the top-right where the minimap is — so it overlaps and is unclickable.
2. Entering the infinite "main" overworld via madrian's door leaves **no return route**;
   only a waystone teleports back to town. (Chosen fix: a persistent return-portal entity.)
3. Tap-to-move commits a target on touch-release and *cancels* on drag, so you can't adjust
   the destination by dragging your finger.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-338 | Menu hub overlay above HUD; close button clear of minimap | agent | pending | — |
| TID-339 | Persistent return portal from the infinite overworld to town | agent | pending | — |
| TID-340 | Tap-to-move drag steering (update target while dragging) | agent | pending | — |

## Acceptance Criteria

- [ ] The menu hub renders above the HUD/minimap; its Close control is fully visible and
      tappable on both portrait and landscape, mobile and desktop.
- [ ] From the infinite overworld the player can reach a visible return portal that takes
      them back to madrian (town) without using a waystone.
- [ ] Dragging after a tap continuously updates the move target and the player follows;
      releasing leaves the player heading to the final position. The virtual joystick still
      works and is not hijacked by tap-to-move.
