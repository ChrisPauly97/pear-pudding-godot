# TID-499: Opt-in Forward+ Renderer on Android

**Goal:** GID-130
**Type:** agent
**Status:** done
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

Override file is the setting (read before scripts run); RendererOptIn static helper with boot lock + fallback detection; SceneManager guard on mobile; Settings toggle on mobile.

## Changes Made

- New `game_logic/RendererOptIn.gd`.
- `project.godot`: `application/config/project_settings_override="user://renderer_override.cfg"` (verified a user:// override changes `rendering_method.mobile` at boot).
- `SceneManager`: `_guard_renderer_opt_in()` in `_ready`.
- `SettingsScene`: mobile-only "Advanced Renderer (restart)" toggle.
- Tests: new `test_renderer_opt_in.gd`.

## Documentation Updates

visual-polish.md: Opt-in Forward+ bullet in the Graphics Quality section.
