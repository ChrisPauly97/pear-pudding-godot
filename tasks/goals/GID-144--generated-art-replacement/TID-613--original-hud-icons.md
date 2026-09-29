# TID-613: B4 — Original HUD Icons

**Goal:** GID-144
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BID-072. 15 game-icons.net SVGs (CC BY) in `assets/icons/hud/`.

## Research Notes

Replace with hand-authored SVGs at the same paths.

## Plan

`tools/generate_hud_icons.py` writes 14 geometric white SVGs at the same paths (import settings unchanged); preview via Godot `Image.load_svg_from_string`; drop the CC BY licence file.

## Changes Made

New generator + 14 SVGs; deleted `LICENSE-game-icons.txt`; `test_hud_icons` licence test → every icon id comes from the generator; HudIcons header comment.

Follow-up (user review): Polish pass: draft_duel is three cards fanned from one pivot, front card marked with a diamond.

## Documentation Updates

CREDITS Icons section, `ui-and-scene-management.md` icon paragraph, `art-sprites.md` (B4 ✓, no third-party sprites remain).
