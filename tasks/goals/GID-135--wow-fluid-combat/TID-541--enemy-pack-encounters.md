# TID-541: Enemy Encounters That Match the World

**Goal:** GID-135
**Type:** agent
**Status:** pending
**Depends On:** TID-540

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A single world enemy summoning a board of ghouls feels wrong. Implement the encounter model chosen in TID-540 so what you see in the world is what you fight.

## Research Notes

- Likely shape (confirm in TID-540): pack enemies (`ghoul_pack`, `undead_horde`) show 2–4 sprites in the world
  (`SpriteRegistry.make_billboard`) and start the battle with those units already on the board; solo enemies/bosses
  fight with their own abilities (spell-like enemy cards) instead of summoning, except thematic summoners (necromancer).
- EnemyRegistry entries gain e.g. `pack: [...]` (starting board) and `abilities: [...]`; `deck` retained for summoners.
- Touch points: `GameState` setup (initial board), `BasicAI`, `CaptureTracker.gd` (capture target), bestiary
  (`docs/agent/bestiary-codex.md`), co-op scaling `CoopBattleScaling.gd`, scripted battles/puzzles unaffected.

- **TID-540 decided Option A** — read `docs/agent/combat-model.md` (Decisions section) first. Use the
  Mentor / Ally / Minion terminology.

- Real time: pack members start on the board (RealtimeCombat gives pre-placed units a half swing);
  solo enemies' ability cards resolve through the enemy cast telegraph (`enemy_cast_start` / `enemy_cast`).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
