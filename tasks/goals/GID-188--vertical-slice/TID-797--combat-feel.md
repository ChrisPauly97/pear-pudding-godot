# TID-797: Combat feel polish pass (hit-stop, impact, cast-bar readability)

**Goal:** GID-188
**Type:** agent
**Status:** done
**Depends On:** TID-794

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Checklist pass on real-time fights in the slice: hit-stop on impacts, screen/token shake scaled by damage, readable enemy cast bars + interrupt feedback, clear focus target, damage-school weak/resist callouts. Every timing as a `CombatTuning` knob.

## Research Notes

- `BattleRealtime.gd`, `RealtimeVisuals.gd`, `SwingFx.gd`, `MomentumHud.gd`, `CombatTuning.gd` (edit via ⚙ Tune).
- Balance bands must stay green (`tests/balance_bands.gd`) — feel changes, not numbers.

## Plan

Audit found most of the checklist already shipped: hit-stop + shake (`hit_feel`, GID-139 / TID-580), punch / sparks /
flash (`BattleJuice`), swing wind-up + impact (`SwingFx`), crit callouts, school-coloured "Weak!" / "Resisted" damage
numbers (TID-752), Heavy Blow warning toast. Gaps fixed here: hit feel hard-coded (not live-tunable), no feel on a
successful interrupt, none on hits taken, killing blow no heavier than a hit, enemy cast bar gave no urgency cue.

## Changes Made

- `CombatTuning`: "Hit feel" group — `feel_stop_1..3`, `feel_shake_1..3`, `feel_taken_shake` (edit live via ⚙ Tune).
- `BattleRealtime.hit_feel` reads those knobs (const `_HIT_FEEL` removed); `hit_feel(2)` on a Kick interrupt and an
  Ally interrupt; killing blow = strength 3; new `taken_feel()` (small shake, no hit-stop) on enemy swings at the hero.
- Enemy cast bar turns red past 66 % (`SwingFx.CAST_URGENT` / `cast_urgency_tint`), the Kick window closing.
  `RealtimeVisuals` kept at 500 lines (two lines folded).
- Hit-stop pauses only the battle clock, so outcomes are unchanged; balance bands pass.
- Tests: 2 more in `test_combat_tuning.gd`. Suite 3652 pass; realtime / in-world / input smokes clean.

## Documentation Updates

- `docs/agent/battle-system.md`: Hit feel note.
