# TID-422: Enemy-Initiated Ambush Penalty + Fair-Warning Indicator

**Goal:** GID-113
**Type:** agent
**Status:** pending
**Depends On:** TID-420

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The "stick" half of the ambush system: if a tracking enemy's chase (TID-420)
actually catches the player while they're in the CHASING alert state (as
opposed to the player walking up to an IDLE enemy, which TID-421 rewards
instead), the player should feel it was their own fault for not reacting — not
a cheap surprise. This task must ship the warning indicator in the same task as
the penalty; do not land the penalty without the warning.

## Research Notes

- Penalty trigger: same `EnemyNPC.engage()` call site as TID-421, but for the
  opposite alert state — `_alert_state == CHASING` (per TID-420's enum) at the
  moment `engage()` fires means the enemy caught the player mid-pursuit, so set
  `edata["enemy_ambush"] = true` instead of `player_ambush`.
- Penalty to apply — mirror TID-421's mechanism choice exactly but inverted
  (enemy gets the advantage instead of the player), applied in the same
  `BattleScene._ready()` spot right after `_apply_gambit_handicaps()`:
  - If TID-421 chose "reduced enemy hero HP", this task's penalty should be its
    mirror: reduced *player* hero HP by the same percentage, OR a missing card
    from the opening hand (thematically "you were caught off guard, you didn't
    have time to prepare") — pick whichever TID-421 didn't use for the bonus so
    the two feel like real opposites, not just "+/- HP" reskinned twice. Decide
    during Plan, but keep it consistent with TID-421's implementation choice so
    both read from the same code shape (e.g. both are HP deltas, or both are
    hand-size deltas — don't mix).
- **Fairness requirement (hard constraint from the goal's acceptance
  criteria):** the player must have a real chance to see the enemy coming and
  react before being caught. This means:
  - A visible state-change indicator the moment `_alert_state` transitions
    IDLE → ALERTED (enemy has entered the TID-420 awareness radius but hasn't
    caught the player yet) — classic "spotted" telegraph. Suggested: a
    billboard `Label3D` above the enemy (mirroring the existing difficulty-pip
    pattern, `EnemyNPC._add_difficulty_pip()`,
    `scenes/world/entities/EnemyNPC.gd:91-112`, which already does
    `Vector3(0, 1.4, 0)` billboard labels) showing something like `"!"` in a
    warning color, or a sprite modulate flash.
  - An audio cue on the ALERTED transition (`AudioManager.play_sfx(...)`,
    already used for `enemy_engage` in `engage()` line 55 — add a distinct
    "enemy_alert" SFX key to `AudioManager.SFX_PATHS`, silently no-ops if the
    wav file is absent per the existing convention documented in
    `docs/agent/battle-system.md` "Battle SFX" section).
  - Per CLAUDE.md's Mobile/Desktop Feature Parity rule: this indicator must be
    visible on both platforms without relying on a keyboard-only signal — a
    3D-space billboard label + minimap ping (mirror the roaming-boss minimap
    treatment in `docs/agent/enemies-and-npcs.md` "Roaming Boss" → "Minimap")
    satisfies this on both.
- Must give the player enough *time* between ALERTED and actually being caught
  to act — this is a function of the awareness radius (TID-420) vs.
  `AUTO_BATTLE_RANGE` vs. `TRACKING_SPEED`; tune the awareness radius generously
  enough during Plan/playtesting that a player who immediately runs has a real
  chance via TID-423's evasion mechanic.
- Same save/resume and duel/rival exclusions as TID-421 — verify both tasks
  land on the same conclusions since they share the `BattleScene._ready()`
  integration point (implement them so the two flags are mutually exclusive:
  an engage can never be both `player_ambush` and `enemy_ambush`).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
