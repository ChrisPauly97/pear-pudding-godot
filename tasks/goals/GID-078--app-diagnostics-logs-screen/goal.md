# GID-078: App Diagnostics Log Screen

## Objective

Add an in-game diagnostics overlay that captures and displays app logs in a scrollable viewer, accessible on both desktop and Android.

## Context

Android doesn't expose logcat to the user at runtime. To diagnose issues in the field — wrong saves, battle bugs, missing drops — we need an in-game log screen that captures important events in a ring buffer and lets the user read them without a PC. The feature follows the mobile/desktop parity rule: reachable from both the pause menu (tap) and keyboard.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-288 | AppLog autoload — ring buffer & log methods | agent | pending | — |
| TID-289 | DiagnosticsScene overlay — scrollable log viewer | agent | pending | TID-288 |
| TID-290 | Wire entry points — pause menu & menu scene buttons | agent | pending | TID-289 |

## Acceptance Criteria

- [ ] `AppLog.info/warn/error()` store timestamped entries in a 200-entry ring buffer and pass through to `print()`
- [ ] Key game events (battle won/lost, enemy engaged, save written, scene entered) are auto-logged via GameBus signal connections in AppLog
- [ ] DiagnosticsScene shows all buffered entries in a scrollable, colour-coded RichTextLabel (green/yellow/red)
- [ ] DiagnosticsScene has a "Clear" button and auto-scrolls to the newest entry on open
- [ ] A "Diagnostics" button appears in the OverworldPauseOverlay and in MenuScene
- [ ] Works identically on Android (reads from in-memory buffer, no file I/O required)
