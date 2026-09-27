# TID-549: Combat Tuning Panel + WoW-Style Timers

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-546

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User asked how WoW handles GCD vs swing timer vs cast times vs cooldowns and wanted all the parameters tunable. Approved: a tuning table + in-game panel, plus the easy wins (spell queue, weapon speed, mana five-second rule, pushback, interruptible enemy casts).

## Research Notes

WoW model summarised in `docs/agent/combat-model.md` → WoW timing model. Real-time numbers were scattered constants in `RealtimeCombat.gd`.

## Plan

One `CombatTuning` table read by `RealtimeCombat`; `CombatTuningPanel` edits it live (clock paused) and persists overrides in the `combat_tuning` setting; add queue window, weapon speed, regen pause, pushback, interrupts.

## Changes Made

- New `game_logic/battle/CombatTuning.gd`: 21 knobs (DEFS: label, default, min, max, step, group), clamp + snap,
  `overrides()` for persistence. `RealtimeCombat` takes a tuning in `_init` and reads every timing from it
  (structural constants kept: MANA_SCALE, MANA_CAP, MAX_ALLIES, MAX_ENEMY_MINIONS, SURGE_DELAY).
- Spell queue: `in_queue_window()`; `BattleRealtime.on_cooldown()` opens in the window; `run_cast` queues the
  cast until the GCD ends ("(queued)" on the cast bar). Instant plays in the window fire up to 0.4 s early.
- Weapon speed: `WeaponData.swing_speed` (axe 3.6, staff 3.2, blade 2.6, wand 2.2, dagger 1.8);
  `main_hand_damage` scales by speed ÷ unarmed speed (same DPS, bigger/smaller hits).
- Five-second rule: any spend pauses regen `mana_regen_delay` s (both sides).
- Pushback: hits on a casting hero add `cast_pushback` s, up to `pushback_max_hits` (enemy in RealtimeCombat,
  player in BattleRealtime). Interrupt: a commanded Ally attack on the enemy hero cancels its cast (card kept,
  enemy GCD starts, "Interrupted X!" toast).
- New `scenes/battle/modules/CombatTuningPanel.gd` (BaseOverlay, modal group): grouped − / + rows, changed
  values highlighted, Reset all / Close. "⚙ Tune" button top-left in real-time battles; T key on desktop.
- Tests: `tests/unit/test_combat_tuning.gd` (6), `test_realtime_combat` migrated to tuning values; realtime smoke
  covers the panel (pauses clock, edits live value, saves) and the Ally-hit interrupt. Suite + smokes green.

## Documentation Updates

`docs/agent/combat-model.md`: WoW timing model + tuning section; rules table points at CombatTuning.
