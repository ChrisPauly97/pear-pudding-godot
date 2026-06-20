# TID-254: Battle Speed Setting — Fast Mode Toggle

**Goal:** GID-069
**Type:** agent
**Status:** done
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

1. Add `var _speed_scale: float = 1.0` field to BattleScene; read `battle_speed` setting in `_ready()` and set `_speed_scale = 0.45` when `"fast"`.
2. Add `func _battle_delay(base: float) -> void` helper that awaits `create_timer(base * _speed_scale, false).timeout`.
3. Replace the three raw `await create_timer(...)` calls in the AI-turn path (1.5 s, 0.5 s, 0.6 s) with `await _battle_delay(...)`.
4. In `SettingsScene._ready()`: add a "Battle Speed" option row with Normal / Fast toggles, reading current value from `SaveManager.get_setting("battle_speed", "normal")` and writing on change via `set_setting("battle_speed", ...)`.

## Changes Made

- `scenes/battle/BattleScene.gd`: added `_speed_scale` field (line 76); reads `battle_speed` setting in `_ready()` (lines 153–154); added `_battle_delay()` helper (lines 2046–2047); replaced `create_timer(1.5)`, `create_timer(0.5)`, `create_timer(0.6)` with `_battle_delay()` calls (lines 2054, 2065, 2087).
- `scenes/ui/SettingsScene.gd`: added Battle Speed option row with Normal/Fast toggle buttons; reads current setting on open and writes on change (lines 78–82).
- `tests/unit/test_xp_reward.gd`: added `test_battle_speed_*` round-trip tests verifying SaveManager stores and retrieves the `battle_speed` key correctly (covers the persisted setting used by BattleScene).

## Documentation Updates

Updated docs/agent/battle-system.md (part of final doc pass).
