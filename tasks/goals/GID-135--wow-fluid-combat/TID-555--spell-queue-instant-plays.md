# TID-555: Spell Queue — Instant Plays Must Not Fire Early

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-549

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Reported: instant (0-cast-time) card plays and instant skill-bar abilities pressed inside the spell-queue
window fire immediately (early) instead of waiting for the GCD to end.

## Research Notes

TID-549 built the WoW-style spell queue: `RealtimeCombat.in_queue_window(side)` is true for the last
`tune.spell_queue` seconds (0.4 s default) of a side's GCD, and `BattleRealtime.on_cooldown()` treats that
window as "not on cooldown" so `_can_local_act()` lets a tap through before the GCD has actually finished.
For a **cast-time** spell (or skill-bar ability), that's fine: `BattleRealtime.run_cast()` starts a visible
cast whose own `_cast_delay` (= the GCD remaining at the moment of the tap) holds it back until the GCD
truly ends — the queue works as designed there.

The bug is that **instant** plays (`cast_time <= 0`) never went through that queuing at all.
`run_cast()` early-returned `false` for `t <= 0.0`, and every caller's pattern is
`if not run_cast(...): finish.call()` — so an instant spell resolved *immediately*, synchronously, the
moment the tap was accepted inside the window, up to `spell_queue` seconds (0.4 s) before the GCD actually
ended. `BattleSkillBar.press()` had the identical bug for its own on-GCD instant abilities (e.g. "Strike",
`cast: 0.0`): it skipped `run_cast` entirely for `cast <= 0.0`, calling `rt.start_gcd()` + `_resolve(slot)`
straight away. TID-549's own Changes Made log named this exactly: *"Instant plays in the window fire up to
0.4 s early."* — a known, called-out gap this task closes.

Minion (non-spell) card placement doesn't go through `run_cast` at all (no cast-time concept for units) and
is out of scope here — tracked as a follow-up, not fixed by this task (see Documentation Updates).

`_can_local_act(ignore_gcd: bool)` on `BattleScene.gd` already exists (added for Ally attack commands,
which are legitimately off-GCD) — this task didn't need to touch it.

## Plan

1. Make `run_cast()` handle `cast_time == 0` through the *same* queuing path as a cast-time spell, instead
   of bailing out early: set `_cast_total = _cast_left = 0`, still compute `_cast_delay` from the side's
   current GCD, and still call `rt.start_gcd()` only once the delay clears. `_tick_cast()` already resolves
   the instant the moment `_cast_left <= 0`, so a `0`-total cast just resolves on the very next tick after
   its delay ends — one frame later than an already-ready GCD would have resolved it before, imperceptible,
   but no longer early relative to the GCD.
2. Guard `_cast_info()`'s `_cast_left / _cast_total` division for `_cast_total == 0` (would be a `0/0` NaN
   for the one tick between the delay clearing and the tick that resolves it) — show it as "(queued)" for
   that tick, same as the delay-phase display.
3. `BattleSkillBar.press()`: route every non-`off_gcd` ability through `run_cast(..., cast_time)` uniformly,
   whether `cast` is `0` or not, instead of special-casing `cast <= 0.0` with a direct `start_gcd` +
   `_resolve` call. `off_gcd` abilities (only "Kick" today, `cast: 0.0`) are unaffected — they bypass the
   GCD/queue entirely, by design (WoW off-GCD actions), resolved immediately as before.
4. Existing `_check_skill_bar` smoke coverage (`tests/realtime_battle_smoke.gd`) presses Strike and checks
   its effect *synchronously* — that assumption is now wrong (Strike resolves one tick later), so it needs
   to wait for `is_casting()` to clear, the same way the existing Mend check already does.
5. Add smoke coverage that a play made inside the queue window doesn't resolve before it's queued and does
   resolve once the GCD ends (`realtime_battle_smoke.gd`, alongside the existing cast-time check — driving
   the actual UI path plus a live ticking clock is a better fit here than a unit test of an isolated
   `BattleRealtime`, since `run_cast` needs a real `BattleScene`).

## Changes Made

- `scenes/battle/modules/BattleRealtime.gd`: `run_cast()` no longer early-returns for an instant
  (`cast_time <= 0`) play — it queues through the same `_cast_delay`/GCD path a cast-time spell uses.
  `_cast_info()` shows "(queued)" instead of dividing by a zero `_cast_total`.
- `scenes/battle/modules/BattleSkillBar.gd`: `press()` now always calls `run_cast(...)` for a non-`off_gcd`
  ability (previously only when `cast > 0.0`); `off_gcd` abilities resolve immediately as before, unaffected.
- `tests/realtime_battle_smoke.gd`: new `_check_spell_queue` — waits into the queue window, confirms an
  instant `run_cast` play doesn't resolve synchronously and does resolve once queued. Updated
  `_check_skill_bar`'s Strike check to wait for the cast to resolve (it no longer lands inside the same
  call), matching the pattern the existing Mend check already used.
- Full suite (2661 tests), gdlint and `scripts/unsafe-hits.sh` clean; `world_scene_smoke`,
  `realtime_battle_smoke` (incl. the new check), `in_world_battle_smoke`, `net_attack_replay_smoke`,
  `coop_pve_ai_turn_smoke` all pass with zero SCRIPT ERROR.

## Documentation Updates

- `docs/agent/combat-model.md` → Known prototype gaps: reworded the input-queue gap to note that TID-555
  closed the instant/skill-bar early-fire case, leaving one-tap targeting and a queue for *targeted* plays
  as the remaining TID-530 scope.
- Logged `tasks/backlog/BID-062--minion-placement-bypasses-gcd-queue.md`: minion (non-spell) card placement
  still bypasses the GCD/queue entirely (it never goes through `run_cast`, which only covers spells and
  skill-bar abilities) — not fixed here; flagged as a follow-up for whichever task next touches minion
  placement in real time (likely TID-530 or TID-545's Ally work).
