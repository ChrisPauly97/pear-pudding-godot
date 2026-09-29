# TID-606: Main Menu Key Art

**Goal:** GID-143
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
