# TID-423: Evasion — Break Pursuit / Outrun a Chasing Enemy

**Goal:** GID-113
**Type:** agent
**Status:** done
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

**New constant:** `IsoConst.ENEMY_GIVEUP_RANGE: float = 9.0` (larger than
`ENEMY_AWARENESS_RANGE` = 6.0, per the research note's requirement).

**Distance-only give-up, no max-duration cap:** checked
`docs/agent/rideable-mounts.md` — mounted `Player._get_move_speed()` is 2×
base, and `IsoConst.PLAYER_SPEED` (6.0) already exceeds `TRACKING_SPEED`
(2.5) even on foot. A fleeing player's distance to the enemy only grows, so
a sustained-distance give-up alone is sufficient — no separate "give up
after N seconds regardless of distance" cap is needed; the only way a chase
runs long is the player moving *toward* or alongside the enemy, in which
case an inevitable catch is the correct outcome, not a timeout escape.

**Mechanics:** `_process()` (already the site of the ALERTED/CHASING tick
from TID-420) grows a new early branch: while `_alert_state != IDLE`, run
`_update_giveup(delta)` before the existing state-tick logic. It resolves
the player (factored the existing lazy-cache lookup out of `_chase_player`
into a shared `_resolve_player()` helper — same lookup was about to be
duplicated a third time), and accumulates `_giveup_timer` while distance >
`ENEMY_GIVEUP_RANGE`, resetting to 0 the instant distance drops back under
(prevents boundary flicker, per the research note). At `_GIVEUP_HOLD_TIME`
= 2.0s sustained, `_give_up_pursuit()` resets `_alert_state` to `IDLE`
(clearing `_alert_timer`/`_giveup_timer` too) — this alone re-arms
TID-421's ambush bonus, since `player_ambush` is derived from `_alert_state
== IDLE` at the next `engage()` call with no separate flag to reset.

**Give-up visual:** new `_show_giveup()`, a fading gray `"?"` billboard
`Label3D` (mirrors `_show_alert()`'s shape/position, inverted color and a
plain fade instead of a pop-in scale) — the "relief" cue from Research
Notes. **No new SFX**: adding one would mean extending `SfxGen.gd`'s
procedural-synthesis key list too (GID-114's bar is "every registered key
is audible"), which is more surface area than this task needs for a
visual-only acceptance criterion ("the enemy visibly gives up"). Scoped out
deliberately, not an oversight.

**`engage_cooldown` non-conflict:** confirmed via BID-058 (filed during
TID-420) that `engage_cooldown` does not exist anywhere in the current
`EnemyNPC.gd` — there is nothing for give-up to conflict with. No action
needed here; BID-058 tracks the separate question of whether it should be
restored.

## Changes Made

- `autoloads/IsoConst.gd`: added `ENEMY_GIVEUP_RANGE: float = 9.0`.
- `scenes/world/entities/EnemyNPC.gd`:
  - `_process()`: early-return on `IDLE` (nothing to give up), then calls new
    `_update_giveup(delta)` before the existing ALERTED/CHASING tick.
  - New `_resolve_player()` — factored out of `_chase_player()`'s lazy
    player-cache lookup so `_update_giveup()` doesn't duplicate it.
  - New `_update_giveup(delta)`: accumulates `_giveup_timer` while distance
    to the player exceeds `ENEMY_GIVEUP_RANGE`, resets to 0 the instant
    distance drops back under; at `_GIVEUP_HOLD_TIME` (2.0s) calls
    `_give_up_pursuit()`.
  - New `_give_up_pursuit()`: resets `_alert_state` to `IDLE`
    (clears `_alert_timer`/`_giveup_timer`), shows `_show_giveup()`.
  - New `_show_giveup()`: fading gray `"?"` billboard, mirrors
    `_show_alert()`'s shape.
- Verified: headless editor import clean; `tests/runner.gd` — 2337 passed, 0
  failed, 1 pending (pre-existing).

## Documentation Updates

- Deferred to TID-424 per the goal's task breakdown.
