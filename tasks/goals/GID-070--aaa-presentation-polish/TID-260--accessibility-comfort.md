# TID-260: Accessibility & Comfort Settings

**Goal:** GID-070
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The settings screen offers only music and SFX volume. There are no accessibility or comfort options: no screen-shake toggle (shake exists in battle since GID-023), no text scaling, and no haptics — `Input.vibrate_handheld()` is never called anywhere despite Android being the primary platform. This task adds the standard comfort trio.

## Research Notes

- `scenes/ui/SettingsScene.gd` — existing sliders persist via SaveManager and apply to AudioManager; follow the same persist/apply pattern for the new options.
- Screen-shake toggle: shake is implemented in `scenes/battle/BattleScene.gd` (~lines 1835–1871, hit flash + camera shake). Gate the shake call on the setting. If TID-255's TransitionManager or other shake sources exist by then, route all shake through one helper that checks the setting.
- Text scale: a global multiplier (e.g. 0.85 / 1.0 / 1.25) applied to font sizes. Fonts are sized viewport-relatively in code per CLAUDE.md (2–2.5% vh); the cleanest hook is a `UIScale.factor` (autoload or SaveManager-read static) that all `vh * x` font computations multiply by. BID-009 notes there is no shared Theme — do NOT build a full Theme system here (that is BID-009's scope); just thread the factor through the existing per-scene sizing helpers, and note any scenes too tangled to convert as follow-up backlog.
- Haptics: `Input.vibrate_handheld(ms)` on Android for: card played (drag-drop release in battle), battle won/lost, chest opened, achievement toast. Hook via existing GameBus signals where possible (`autoloads/GameBus.gd` is the signal hub; note BID-006 — some battle signals are declared but never emitted, so verify each hook point actually fires). Default ON on Android, hidden or no-op on desktop (`OS.has_feature("mobile")`).
- Persist all three via SaveManager's field-migration system (defaults: shake on, scale 1.0, haptics on). If TID-257 moved settings to a global settings file, follow that.
- UI: extend SettingsScene with viewport-relative controls per CLAUDE.md; CheckButton for toggles, OptionButton or slider for text scale.

## Plan

Extend `SettingsScene.gd` with three new controls: screen-shake toggle (`CheckButton`), text scale option (`OptionButton` Small/Normal/Large), haptics toggle (Android-only `CheckButton`). Persist all three via existing `SaveManager.get_setting/set_setting` pattern with defaults (shake on, scale 1.0, haptics on). Gate `BattleScene` camera shake on the setting. Add `_haptic(ms)` helper to `BattleScene` that calls `Input.vibrate_handheld(ms)` on Android when haptics enabled. Add haptic calls for card_play, battle_win, battle_lose, and chest open.

## Changes Made

- **MODIFIED `scenes/ui/SettingsScene.gd`**: Expanded panel height to 0.75vh. Added "Audio" and "Accessibility & Comfort" section headers. Added `_add_toggle_row(label, key, default)` and `_add_option_row(label, key, options, scale_map)` helpers. Screen-shake `CheckButton` persists to `"screen_shake"` setting. Text scale `OptionButton` (Small=0.85/Normal=1.0/Large=1.25) persists to `"text_scale"`. Haptics `CheckButton` shown only when `OS.has_feature("mobile")`, persists to `"haptics"`.
- **MODIFIED `scenes/battle/BattleScene.gd`**: Added `_haptic(duration_ms: int)` — calls `Input.vibrate_handheld(duration_ms)` gated on `OS.has_feature("mobile") and SaveManager.get_setting("haptics", true)`. `_trigger_shake()` now gates on `SaveManager.get_setting("screen_shake", true)`. `_haptic(20)` after each `play_sfx("card_play")` (3 sites). `_haptic(120)` on battle_win. `_haptic(80)` on battle_lose.
- **MODIFIED `scenes/world/WorldScene.gd`**: Chest open emits `Input.vibrate_handheld(40)` on Android when haptics enabled.

## Documentation Updates

Updated `docs/agent/ui-and-scene-management.md` — SettingsScene section updated with new accessibility controls.
