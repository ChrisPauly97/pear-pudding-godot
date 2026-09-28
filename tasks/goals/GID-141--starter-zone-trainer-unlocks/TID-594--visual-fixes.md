# TID-594: Visual Finish Fixes

**Goal:** GID-141
**Type:** agent
**Status:** pending
**Depends On:** TID-593

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Fix the top-ranked findings from TID-593 on the first-30-minutes path. Scope is the ranked list; anything large gets a
backlog item instead.

## Research Notes

- Follow CLAUDE.md UI rules (viewport-relative sizes, `_UiUtil` factories, `UiTheme`), Sprite3D rules (depth clipping,
  `SpriteOutline.apply()` for custom materials), `.uid` sidecars for any new resource, const preloads (Android).
- Re-capture the same screenshots after fixing for a before/after pair in the task file.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
