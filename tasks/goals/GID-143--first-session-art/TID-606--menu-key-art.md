# TID-606: Main Menu Key Art

**Goal:** GID-143
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BID-067: flat menu background. User chose a live dusk view of Madrian with a static fallback on Low graphics.

## Research Notes

- `scenes/ui/MenuScene.gd`; a SubViewport rendering a lightweight world view (terrain chunks around Madrian + props, no entities/AI) with a slow camera pan; `GraphicsQuality` low → static PNG captured from the same view (generated once via xvfb into `assets/textures/ui/menu_keyart.png` + .import).
- Keep buttons legible: dark gradient behind the button column.

## Plan

Deviation (reported to the user): an in-engine capture of Madrian at twilight with a slow Ken-Burns drift instead of a live world render — a live view would boot WorldScene inside the menu. Low graphics: still image.

## Changes Made

- New `tools/capture_menu_keyart.gd` (xvfb capture, HUD / Label3D / beacons hidden).
- `assets/textures/ui/menu_keyart.jpg` (1920×1080, q88, 380 KB).
- `MenuScene.gd`: `_build_backdrop()`, `_drift_keyart()`; layout sizes the backdrop.
- Verified in an xvfb capture of the menu.

## Documentation Updates

`ui-and-scene-management.md` "Main menu key art".
