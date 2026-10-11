# TID-783: Runs: rift / spire ladders and siege gauntlets

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-781

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Multi-fight sims with HP carried between fights: a rift tier ladder (floors, guardian floor, boons, drafted picks)
and a town-siege gauntlet. Bands: clear rate per rift tier falls smoothly; a level-appropriate siege is clearable.

## Research Notes

- `game_logic/spire/RiftDefs.gd`, `SpireFloorGen.gd`, `SpireDraft.gd`; `BattleModifiers._build_rift_deck` (own deck +
  run picks + buff boons); `docs/agent/rifts.md`; `autoloads/save_manager/SaveSpire.gd`.
- Siege: `SaveSiege.gd` (`get_active_siege`, `hero_hp` carry-over — BattleScene ~l.502), `TownSiege.gd` module.
- Draft picks need a bot policy (simple: best-power pick).

## Plan

## Changes Made

## Documentation Updates
