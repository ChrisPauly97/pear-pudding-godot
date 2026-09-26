# TID-545: Hero Kit — Weapon Auto-Attack, Ally Cap, Faster Start

**Goal:** GID-135
**Type:** agent
**Status:** pending
**Depends On:** TID-540

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Option A core (see `docs/agent/combat-model.md`): the hero fights. Weapon auto-attack each turn, Ally cards capped per deck and played into 3 Ally slots (drawn normally, never pre-deployed), 3-mana start + 4-card opening hand.

## Research Notes

- Battle state: `game_logic/battle/GameState.gd` (setup, turn start mana), `PlayerState.gd` (opening draw),
  `HeroState.gd` (hp 30, add `attack`/`attacked_this_turn`), `ZoneState.gd` (5 slots — make slot count per player).
- Weapon: `data/WeaponData.gd` add `hero_attack: int`; `WeaponRegistry`; applied in `BattleModifiers.gd`.
  Hero attack UI: tap hero → target (reuse `BattleTargeting.gd`), and TID-530 one-tap attack.
- Ally cap: deck builder validation (GID-003 min 5/max 30; `docs/agent/inventory-and-deck.md`), `DeckAutoFill.gd`,
  loadouts `SaveLoadouts.gd`; migration in `SaveMigrations.gd` moves excess minion cards back to the collection.
- PvP (`scenes/battle/net/BattleNet.gd`, BattleNetProtocol) must serialise new hero fields (`to_dict/from_dict`);
  mid-battle save (GID-034) too. AI: `ai/BasicAI.gd` must use enemy hero attack when enemy has a weapon (solo shape).
- Budget test from TID-527 (`BattlePacing`) should still hold.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
