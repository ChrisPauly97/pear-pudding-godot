# TID-422: Enemy-Initiated Ambush Penalty + Fair-Warning Indicator

**Goal:** GID-113
**Type:** agent
**Status:** done
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

**Penalty mechanism already landed:** TID-421's commit implemented
`BattleScene._apply_ambush_modifiers()`'s `enemy_ambush` branch alongside
`player_ambush` (same integration point, same function) — reduces the
*player's* hero `health`/`max_health` to `round(max_health * 0.8)` (floor
10), mirroring `player_ambush`'s enemy-HP reduction, and calls
`BattleResultUI.show_ambush_banner(false)` ("Ambushed!", red). `EnemyNPC.
engage()` already sets `edata["enemy_ambush"] = (_alert_state ==
AlertState.CHASING)`. This task's remaining scope is exclusively the
fair-warning indicator.

**Fair-warning indicator:** reuse `EnemyNPC._show_alert()` (the existing "!"
billboard pop-in, already used by `engage()`'s own beat) plus
`AudioManager.play_sfx("enemy_alert")` — both already exist, no new SFX key
needed (the research note's suggestion to add one was written against a
version of the file that predates confirming `"enemy_alert"` was already
registered in `AudioManager.SFX_PATHS`). Call both from
`_on_awareness_entered()` right after the `IDLE -> ALERTED` transition —
this is a 3D world-space billboard label + audio cue, inherently visible on
both desktop and mobile with no keyboard-only or touch-only path, so it
satisfies CLAUDE.md's Mobile/Desktop Feature Parity rule without a minimap
addition. Skipping the minimap-ping suggestion from Research Notes as
redundant polish, not required for parity — documented here as the Plan
decision.

**Timing check (no radius/speed retuning needed):** worst case for "enough
time to react" is the player motionless right as `ALERTED` fires at the
awareness-radius edge (distance ≈ `ENEMY_AWARENESS_RANGE` = 6.0). The enemy
holds for `_ALERT_REACTION_TIME` = 0.4s, then must close
`6.0 - AUTO_BATTLE_RANGE(1.5)` = 4.5 units at `TRACKING_SPEED` = 2.5/s ≈
1.8s more — roughly 2.2s total before contact if the player does nothing.
`IsoConst.PLAYER_SPEED` (6.0) already exceeds `TRACKING_SPEED` (2.5), so a
player who reacts by simply moving away at any point during that window
opens the distance and is never caught at all — the constants already give
a generous, fair window. No changes to `ENEMY_AWARENESS_RANGE`,
`AUTO_BATTLE_RANGE`, or `TRACKING_SPEED`.

**Mutual exclusivity:** already guaranteed by construction (TID-420's enum +
TID-421's `if/elif` in `_apply_ambush_modifiers`) — no additional guard
needed here.

## Changes Made

- `scenes/world/entities/EnemyNPC.gd`: `_on_awareness_entered()` now calls
  `_show_alert()` + `AudioManager.play_sfx("enemy_alert")` on the `IDLE ->
  ALERTED` transition (reused existing "!" billboard/SFX, no new assets).
- Penalty mechanism (`enemy_ambush` branch of
  `BattleScene._apply_ambush_modifiers()`, `"Ambushed!"` banner) landed in
  TID-421's commit since both flags share one integration point — see that
  task's Changes Made for the code.
- Verified: headless editor import clean.

## Documentation Updates

- Deferred to TID-424 per the goal's task breakdown (dedicated docs task
  covering all of TID-420–423 in one pass).
