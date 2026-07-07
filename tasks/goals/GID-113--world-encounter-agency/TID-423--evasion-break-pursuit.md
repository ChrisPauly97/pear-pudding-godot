# TID-423: Evasion — Break Pursuit / Outrun a Chasing Enemy

**Goal:** GID-113
**Type:** agent
**Status:** pending
**Depends On:** TID-420

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Without this task, TID-420's pursuit is a death sentence — once alerted, a
tracking enemy would chase forever and the player could never do anything but
fight. This task adds the "give up" path that makes evasion a real player
choice, and is what TID-422's fair-warning indicator is warning the player
*for* (a reason to react other than "fight is now inevitable").

## Research Notes

- Uses TID-420's `_alert_state` enum (IDLE / ALERTED / CHASING, or similar).
  Add a give-up condition evaluated in `EnemyNPC._process(delta)` (already
  ticking `engage_cooldown` there, lines 29-31 — extend the same function
  rather than adding a second per-frame hook):
  - Track distance to player continuously while `ALERTED`/`CHASING`.
  - If distance exceeds a "give-up radius" (larger than the TID-420 awareness
    radius — needs its own `IsoConst` constant, e.g. `ENEMY_GIVEUP_RANGE`) for a
    sustained duration (a few seconds, not instant on one frame, to avoid flicker
    at the boundary — track an accumulating timer that resets if the player
    re-enters range), transition back to IDLE: stop moving, clear any alert
    indicator (TID-422), and re-enable ambush-ability (TID-421) since the enemy
    is unaware again.
  - Consider also giving up after a maximum absolute chase duration regardless
    of distance (prevents an enemy chasing across an entire biome if the
    player is moving at exactly its speed) — decide during Plan whether this is
    needed given `TRACKING_SPEED` (2.5) vs. player movement speed (check
    `docs/agent/camera-and-player.md` for the player's base move speed and any
    mount speed multiplier from `docs/agent/rideable-mounts.md` — a mounted
    player should very plausibly be able to outrun ground enemies, which is a
    good design signal that distance-based give-up alone may be sufficient).
- Visual feedback on giving up: mirror TID-422's alert indicator in reverse —
  the `"!"` label should disappear or change to something like a fading `"?"`
  as the enemy "loses" the player, giving a clear moment of relief rather than
  the enemy just silently stopping. Consider a short SFX here too
  (`AudioManager.play_sfx(...)`, same convention as TID-422's alert SFX).
- Must not fight TID-420's chase movement — the state machine here is purely
  about *transitions* (ALERTED/CHASING → IDLE), not the movement itself, which
  TID-420 already owns. Keep this task's logic reading `_alert_state` and
  writing to it, not duplicating movement code.
- Confirm this doesn't conflict with `engage_cooldown` (existing field,
  `EnemyNPC.gd` line 11, set to 3.0s by `SceneManager` after flee/respawn per
  `docs/agent/enemies-and-npcs.md` "Engage cooldown" section) — an enemy that
  gave up a chase should NOT also be under `engage_cooldown` unless it was
  separately triggered by an actual flee-from-battle; these are two different
  concepts (pre-battle evasion vs. post-battle immunity window) and must not be
  merged into one field.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
