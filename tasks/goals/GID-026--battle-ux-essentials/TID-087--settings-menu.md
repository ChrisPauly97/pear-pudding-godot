# TID-087: Settings Menu with Volume Sliders

**Goal:** GID-026
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

There is no settings UI. Players cannot adjust music or SFX volume. AudioManager has separate channels for music and SFX (GID-004) but no way to control them from the UI.

## Research Notes

- New scene `scenes/ui/SettingsScene.gd` — a simple panel with two HSlider controls
- Settings to expose (minimum viable):
  - Music Volume (0.0 → 1.0 slider, default 0.5)
  - SFX Volume (0.0 → 1.0 slider, default 1.0)
- Apply immediately on slider change: set `AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))` for the relevant bus; check AudioManager for which buses are named "Music" and "SFX"
- Persist values in `SaveManager` — add `settings: Dictionary` field (key: setting name, value: float); load on startup and apply to AudioServer buses
- Entry points: "Settings" button on MenuScene AND accessible from the pause menu (TID-088)
- Back button returns to wherever settings were opened from (use SceneManager stack or a `_return_scene` var)
- Follow CLAUDE.md UI sizing; sliders should be ~60% viewport width, controls sized with vh fractions

## Plan

- Add `settings: Dictionary` to `SaveManager`, v8 migration backfills empty dict for old saves
- Add `get_setting(key, default)` / `set_setting(key, value)` to SaveManager
- Add `set_music_volume(linear)`, `get_music_volume()`, `set_sfx_volume(linear)`, `get_sfx_volume()` to AudioManager
- Apply saved settings in `SceneManager.continue_game()` via `_apply_audio_settings()`
- Create `scenes/ui/SettingsScene.gd` — overlay (extends Control, emits `closed`)
  - Two rows: Music Volume + SFX Volume HSlider + % label
  - Sliders apply immediately; persist via `SaveManager.set_setting()`
  - Close button + tap-backdrop to dismiss + Escape key
- Add Settings button to `MenuScene.tscn` + wire in `MenuScene.gd`
- SettingsScene is also opened from pause menu (TID-088)

## Changes Made

- `autoloads/SaveManager.gd`: added `settings` field, v8 migration, `get_setting`/`set_setting`
- `autoloads/AudioManager.gd`: added `set_music_volume`, `get_music_volume`, `set_sfx_volume`, `get_sfx_volume`
- `autoloads/SceneManager.gd`: added `_apply_audio_settings()`, called from `continue_game()`
- Created `scenes/ui/SettingsScene.gd` — overlay with music + SFX volume sliders
- `scenes/ui/MenuScene.tscn`: added `SettingsButton` node to VBox
- `scenes/ui/MenuScene.gd`: wired `_settings_btn`, added `_on_settings()` handler

## Documentation Updates

Updated `docs/agent/ui-and-scene-management.md` with SettingsScene details.
