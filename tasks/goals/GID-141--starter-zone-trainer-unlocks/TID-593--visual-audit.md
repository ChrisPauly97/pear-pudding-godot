# TID-593: First-30-Minutes Visual Finish Audit

**Goal:** GID-141
**Type:** agent
**Status:** pending
**Depends On:** TID-591

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Appeal weakness #4: the pixel-art-in-3D look varies in finish between older and newer systems. Audit exactly what a new
player sees in their first 30 minutes (menu → biome pick → Madrian → outskirts → first battles → trainer/quest UI).

## Research Notes

- Capture screenshots headless/with the automation bridge used in earlier polish goals (see GID-131..134 task files for
  the capture approach, and `docs/agent/visual-polish.md`). Portrait + landscape.
- Checklist: old vs new sprite pack art (`docs/agent/art-sprites.md` manifest), missing outlines (`SpriteOutline`),
  contact shadows (`CharacterPresence`), UI not using `UiTheme`/factories (hand-styled StyleBoxFlat, hard-coded px),
  fonts (Cinzel titles), battle backdrop, name tags, placeholder textures from `TextureGen`, inconsistent icon sets.
- Output: a ranked findings table in this task file (screen, issue, file, fix size). Log leftovers as BID items.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
