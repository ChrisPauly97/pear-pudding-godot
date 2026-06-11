# TID-254: Battle Speed Setting — Fast Mode Toggle

**Goal:** GID-069
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Enemy turns and battle animations run on fixed `await` timer delays. After a few dozen battles the forced waiting is pure friction — players who have internalized the flow want it faster. Add a persisted battle-speed setting (Normal / Fast) that scales the delays, exposed in the existing Settings overlay.

## Research Notes

- **Delay sites:** `scenes/battle/BattleScene.gd` — `await get_tree().create_timer(1.5, true).timeout` (line 1203), `0.5` (line 1209), `0.6` (line 1226). Audit the whole file for other `create_timer` waits in the AI-turn / attack-animation paths (boss banner at `_BOSS_BANNER_DURATION` can stay fixed — it's informational, shown once).
- **Implementation:** a single helper, e.g. `func _battle_delay(base: float) -> void: await get_tree().create_timer(base * _speed_scale, true).timeout`, with `_speed_scale` read once in `_ready()` from settings (1.0 normal, 0.4–0.5 fast). Replacing the raw awaits with the helper keeps the change mechanical and auditable.
- **Settings storage:** `SaveManager.set_setting(key, value)` / settings dict already exist (used by `music_volume`, `sfx_volume` — see `docs/agent/ui-and-scene-management.md` SettingsScene section). Add `battle_speed` (String `"normal"`/`"fast"` or float scale; prefer the string enum for forward compatibility with a possible "very fast"). Confirm migration behavior: settings are read with defaults via `get_setting`, so missing keys need no migration.
- **Settings UI:** `scenes/ui/SettingsScene.gd` — overlay with two HSliders, opened from MenuScene and the BattleScene pause overlay. Add a "Battle Speed" row with two toggle buttons (Normal / Fast) — touch-friendly, viewport-relative sizing. Applying mid-battle: SettingsScene is reachable from the battle pause menu, so re-read the setting when the pause overlay closes (or have BattleScene read `_speed_scale` lazily per delay call — simplest and always current).
- **Scope guard:** do NOT scale tween-based card movement/attack animations differently per call site unless they're awaited in the turn flow; if tweens gate the AI loop, scale their durations with the same `_speed_scale`. Player-facing input timing (drag, targeting) is untouched.
- **Tests:** the helper is await-based UI code; testable surface is the setting itself (SaveManager round-trip) and that `_speed_scale` maps `"fast"` → expected factor. Keep BattleScene logic changes minimal so existing battle tests stay green.
- **Mobile parity:** toggle buttons, no keyboard shortcut needed (but harmless to add none).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
