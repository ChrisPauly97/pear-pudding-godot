# TID-752: Combat UI: school-coloured numbers, Weak!/Resisted, nameplate icons

**Goal:** GID-181
**Type:** agent
**Status:** done
**Depends On:** TID-749, TID-750

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players must see why a hit was big or small, or schools are invisible numbers.

## Research Notes

- Floating numbers: `scenes/battle/BattleFx.gd` `spawn_float_labels` L231 / `spawn_float_label(pos, text, color, amount)` L251. Feed the resolver's `outcome` through; colour by school using `MagicTypes` colours (physical = neutral white/grey); suffix text "Weak!" / "Resisted" / "Immune".
- Real-time presentation: `scenes/battle/modules/RealtimeVisuals.gd` (unit bars, hero tokens), `SwingFx.gd` for auto-attack impacts. Net replay: `scenes/battle/net/NetBattleFx.gd` carries fx in state mirrors — outcome must ride along for PvP/co-op viewers.
- Nameplate/hero strip school icons: small coloured pips for weak (and resist) schools. Until TID-753 lands show all; TID-753 gates by bestiary knowledge.
- UI sizing relative to viewport, factories from `UiUtil` (CLAUDE.md). Mobile parity: icons tappable for a tooltip.

## Plan

- Record the matchup on the target, not the call site: `DamageResolver.deal` calls `note_hit(school, outcome)` on the HeroState / CardInstance it hits (serial +1 per hit). The state mirror carries the fields, so PvP / co-op viewers need no protocol change, and the ~30 resolver call sites are untouched.
- Damage numbers come from the existing snapshot diff in `BattleFx.spawn_float_labels` (covers turn-based, real-time, and net replay). Immune (0 HP lost) is labelled from the serial advancing.
- Pure rules in `game_logic/battle/SchoolFeedback.gd`; pips in `scenes/battle/modules/SchoolPips.gd`, one `known_profile(enemy_type)` seam for TID-753.

## Changes Made

- `game_logic/battle/SchoolFeedback.gd` (new, pure): `school_color`, `outcome_word`, `damage_text`, `pips_for`, `pip_tooltip`, `hit_record`.
- `game_logic/battle/HeroState.gd`, `CardInstance.gd`: `hit_school` / `hit_outcome` / `hit_serial`, `note_hit()`, serialized in `to_dict` / `from_dict`.
- `game_logic/battle/DamageResolver.gd`: `deal()` calls `note_hit` on the target.
- `scenes/battle/BattleFx.gd`: `spawn_float_labels` colours each HP loss by school and suffixes "Weak!" / "Resisted"; immune labels; snapshot entries carry `unit`.
- `game_logic/battle/RealtimeCombat.gd` + `scenes/battle/modules/BattleRealtime.gd`: heavy blow label uses the resolver's outcome.
- `scenes/battle/modules/SchoolPips.gd` (new) + `RealtimeVisuals.gd`: enemy chip row under the real-time enemy token; tap or hover gives the tooltip.
- Tests: `tests/unit/test_school_feedback.gd` (new, 13 tests).

**Deviations:** pips are on the real-time enemy token only (turn-based enemy strip not done). Swing impact sparks (`SwingFx`) are not tinted by school; the floating number carries the school colour. The attack fx replay in NetBattleFx is unchanged; receivers get outcomes through the state mirror instead.

## Documentation Updates

- `docs/agent/damage-schools.md`: new "Combat feedback (TID-752)" section, test list, integrations.
