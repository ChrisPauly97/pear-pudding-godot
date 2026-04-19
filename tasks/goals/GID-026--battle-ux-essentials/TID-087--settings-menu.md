# TID-087: Settings Menu with Volume Sliders

**Goal:** GID-026
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
