# TID-576: Auto-Attack Toggle & Essence Siphon

**Goal:** GID-139
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Mana came only from a slow regen clock, so most GCDs were idle.

## Plan

`RealtimeCombat.auto_attack` (player) gates `_tick_hero`; `_regen_mult` scales
player regen by `fighting_regen_mult` (on) / `focus_regen_mult` (off).
`on_player_hit(dmg, builder)` siphons `siphon_per_damage` mana per damage from hero
swings and damaging skill-bar abilities. Strike → cost 0, cooldown 0, 2 dmg.
`player_gcd` 1.5 → 1.2, `mana_regen_delay` 2 → 1. Toggle button + F in `MomentumHud`.

## Changes Made

- `CombatTuning`: Momentum knob group; GCD / regen-delay defaults.
- `RealtimeCombat`: auto_attack, _regen_mult, toggle_auto_attack, on_player_hit.
- `SkillBar`: Strike filler; damaging abilities report `dealt` and feed momentum.
- `scenes/battle/modules/MomentumHud.gd` (new), wired from `BattleRealtime`.
- `TutorialRegistry` rt_intro text. Tests: `test_combat_momentum`, skill bar / smoke updates.

## Documentation Updates

`docs/agent/combat-model.md` — Momentum section.
