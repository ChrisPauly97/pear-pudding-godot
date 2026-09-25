# TID-499: Opt-in Forward+ Renderer on Android

**Goal:** GID-130
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Flagship phones can run Forward+, which enables the existing real volumetric fog/SSAO path unchanged.

## Research Notes

- Renderer is fixed at boot. `application/config/project_settings_override` = `user://renderer_override.cfg` lets a setting write `rendering/renderer/rendering_method.mobile="forward_plus"` for the next launch.
- Crash guard: boot lock file in `user://`; if a Forward+ boot never clears it, next boot deletes the override.
- Settings toggle (mobile only) under Graphics, with a 'restart required' note.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
