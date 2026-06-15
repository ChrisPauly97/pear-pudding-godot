# TID-229: Fix lambda signal-connection leaks & overlay ownership

**Goal:** GID-064
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

WorldScene connects fresh **lambdas** to long-lived singleton signals every time a map
loads. Unlike bound-method connections, lambda connections are not auto-removed when the
owning node is freed, and SceneManager frees/recreates WorldScene on every map
transition. Connections accumulate for the process lifetime; each emission invokes stale
callables against freed nodes (`_coin_label.text`, `_refresh_xp_bar`) — runtime errors
after the first door transition, growing per map.

## Research Notes

Leak sites (verified):
- `scenes/world/WorldScene.gd:364` — lambda on `GameBus.battle_won`
- `scenes/world/WorldScene.gd:387` — lambda on `SceneManager.save_manager.coins_changed`
- `scenes/world/WorldScene.gd:410` — lambda on `GameBus.xp_changed`

Fix options (pick per site):
- Convert to bound methods (`connect(_on_battle_won)`) — auto-disconnected on free.
  Preferred where the lambda body is more than a line.
- Or disconnect explicitly in `_exit_tree()`.
- `CONNECT_ONE_SHOT` only where a single fire is actually correct (probably none here).

Sweep for the same pattern elsewhere: grep for `\.connect(func` across scenes/ and check
each connection target — if the target is an autoload or `SceneManager.save_manager`
and the connecting node is scene-lifetime, it leaks. Known-clean (verified by audit):
`GameBus.hud_message_requested` / `story_scroll_collected` use bound methods.

Also in scope — overlay double-ownership cleanup (low severity, same theme):
- `scenes/ui/SettingsScene.gd:127-129` + `scenes/ui/MenuScene.gd:51`, and
  `scenes/ui/JournalScene.gd:184-186` + `autoloads/SceneManager.gd:366-372`: overlays
  `queue_free()` themselves on close *and* their creator queue_frees them on the
  `closed` signal. Double queue_free is currently harmless but the inconsistent
  ownership invites use-after-free edits. Pick one owner (SceneManager, matching all
  other overlays) and remove the self-free.

Verification: transition through 3+ doors (madrian → dungeon → back), win a battle, and
confirm no "callable on freed instance" errors in the log. No automated test covers
this; a manual headless repro script is acceptable.

## Plan

Convert the 3 leaking lambda connects on long-lived singleton signals to bound methods (auto-disconnected when WorldScene is freed). Also convert the 4 tap-cancel lambda connects to direct `_clear_dest_marker` connects (GDScript 4 drops excess signal args for callables with fewer params). Remove self-free from JournalScene and SettingsScene `_close()` — SceneManager/MenuScene already queue_free them via the `closed` signal.

## Changes Made

- **`scenes/world/WorldScene.gd`**:
  - Added `var _xp_label: Label` instance variable.
  - Converted `GameBus.battle_won` lambda → `_on_battle_won(_result: Dictionary)` bound method.
  - Converted 4 lambda `_clear_dest_marker` connects → direct `_clear_dest_marker` connects (Godot 4 discards extra signal args for shorter-arity callables).
  - Converted `SceneManager.save_manager.coins_changed` lambda → `_on_coins_changed(n: int)`.
  - Converted `GameBus.xp_changed` lambda (which captured local `xp_lbl`) → `_on_xp_changed(_xp: int, _level: int)`; promoted `xp_lbl` to `_xp_label` instance var.
  - Added `_on_battle_won`, `_on_coins_changed`, `_on_xp_changed` methods.
- **`scenes/ui/SettingsScene.gd`**: Removed `queue_free()` from `_close()` — MenuScene is the owner and already calls it via `closed.connect(overlay.queue_free)`.
- **`scenes/ui/JournalScene.gd`**: Removed `queue_free()` from `_close()` — SceneManager is the owner and calls it in `_on_journal_closed()`.

## Documentation Updates

None required.
