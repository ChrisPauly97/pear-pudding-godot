# TID-550: Skill Cards as Reusable Abilities with Cooldowns

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-549

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User approved (2026-09-26): skill cards become WoW-style abilities — always available on a small skill bar with their own cooldowns (e.g. 8 s / 30 s / 2 min) — while normal deck cards stay single-use (the hand is their cooldown).

## Research Notes

- Skill cards come from trainers (TID-537). Real-time play paths: `BattleRealtime.run_cast` wraps the solo spell
  paths; GCD / queue in `RealtimeCombat` + CombatTuning.
- Needs: `CardData.cooldown` (s) or a skill-card table, a skill bar UI row (RealtimeVisuals, near your token),
  per-card cooldown sweep, off-GCD flag for utility skills (e.g. an interrupt "Kick" — replaces the Ally-hit
  interrupt as the primary counterplay), tuning knob for a global cooldown multiplier.

## Plan

User scoped it (2026-09-26) to a small bar so the game stays a TCG: 3 fixed slots of weaker, reliable
skills with their own cooldowns; deck spells stay stronger and single-use. Default skills now; trainers
(TID-537) fill `SaveManager.skill_bar` later.

## Changes Made

- `game_logic/battle/SkillBar.gd` (new): ability table (Strike / Mend / Kick), cooldowns, blocker, apply.
- `scenes/battle/modules/BattleSkillBar.gd` (new): buttons + cooldown shade in the status box, keys 1–3.
- `BattleRealtime`: `skills` field, `run_cast(..., cast_time)` override, `is_casting()`, `toast()`,
  `lunge_at()`, cast bar shows an ability's own mana cost.
- `CombatTuning`: `skill_cooldown` knob. `SaveManager`: `skill_bar` persisted field.
- Tests: `tests/unit/test_skill_bar.gd`; `realtime_battle_smoke` presses Strike and Mend.

## Documentation Updates

`docs/agent/combat-model.md` — Skill bar section; CLAUDE.md BattleRealtime row.
