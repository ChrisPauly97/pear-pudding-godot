# TID-609: B0 — Delete Unreferenced Art

**Goal:** GID-144
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BID-068.

## Research Notes

Enemy walk frames are never loaded (only Maiteln animates — `SpriteRegistry.maiteln_walk_frames`). Dead: `characters/enemy_undead{,_walk_1..4}.png`, `pixel_art/wizard_walk_{1..4}_pixel.png` (+ .import).

## Plan

Verify no references (grep .gd/.tscn/.tres/.py), git rm the PNGs + .import, fix CREDITS/art-sprites.

## Changes Made

Deleted 5 old 0x72 undead PNGs and 4 hand-made wizard walk frames (+ .import).

## Documentation Updates

`art-sprites.md` roadmap row B0 marked done; CREDITS per-slot row.
