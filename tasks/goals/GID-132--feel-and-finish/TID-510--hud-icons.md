# TID-510: HUD Button Icons

**Goal:** GID-132
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Text-only HUD buttons ('[D] Dig', 'Menu').

## Research Notes

HUD actions registered via `WorldHUD.register_action(id, label, zone, cb)`. Icons can be drawn procedurally (TextureGen style) to avoid asset sourcing.

## Plan

game-icons.net SVGs (CC BY 3.0) via npm, imported at 128 px; HudIcons registry applied inside register_action; fixed map/coin labels overlapping the pause button.

## Changes Made

- New `assets/icons/hud/` (14 SVGs + .import, licence), `scenes/ui/HudIcons.gd`.
- `WorldHUD.register_action` applies icons; `WorldScene` moves map/coin labels right of pause.
- `CREDITS.md` Icons section. Tests: new `test_hud_icons.gd`. Visual check with HUD.

## Documentation Updates

ui-and-scene-management.md: Icons paragraph under HUD action registry.
