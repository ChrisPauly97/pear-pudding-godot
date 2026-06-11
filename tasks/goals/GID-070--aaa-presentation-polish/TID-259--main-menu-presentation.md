# TID-259: Main Menu & Title Presentation

**Goal:** GID-070
**Type:** agent
**Status:** pending
**Depends On:** TID-257

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The main menu (`scenes/ui/MenuScene.gd` / `.tscn`) is a static "Pear Pudding TCG" label over centered buttons — no animated title, no version label, no backdrop. First impressions set the quality bar for the whole game; this task gives the title screen AAA-grade presentation.

## Research Notes

- Current state: static title Label, vertical button column (Continue / New Game / Settings / etc.), Continue auto-hides without a save. After TID-257, Continue/New Game route through the slot-select UI — build presentation on top of that flow.
- Presentation elements to add:
  - Animated title treatment: tweened fade/slide-in on load, subtle idle motion (e.g. slow scale breathing or a shader shimmer). Use Tween, no per-frame _process work.
  - Backdrop: a live or pre-rendered scene rather than flat color — cheapest convincing option is a slowly panning rendered world vignette (a small static map chunk with the day/night tint shader), or a parallax layered pixel-art sky. Keep it cheap on Android.
  - Version label bottom-corner: read from `ProjectSettings.get_setting("application/config/version")` — set that in project.godot if absent.
  - Button hover/focus/press feedback: tween scale or color modulate; gives TID-258's focus navigation visible styling for free on this scene.
  - Optional splash: Godot boot splash image via project settings (`application/boot_splash/*`).
- Audio: AudioManager (`autoloads/AudioManager.gd`) exists; spec lists music as out of scope — do not add menu music; ambient (TID-261) may cover menu later.
- All sizing viewport-relative per CLAUDE.md; any new shader/.tres needs a .uid sidecar and preload() per CLAUDE.md.
- New textures: existing art is generated via `game_logic/TextureGen.gd` patterns — prefer procedural over binary assets.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
