# TID-543: Persistent Hero HP & Healing (Food, Early Heals)

**Goal:** GID-136
**Type:** agent
**Status:** pending
**Depends On:** TID-540, TID-545

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User decision (TID-540): hero HP carries over between fights with slow out-of-combat regen and a full heal in towns/beds. Healing must be available early: more low-level hero heal spells, food consumables (WoW-style eat-to-regen out of combat) alongside the existing persistent potions.

## Research Notes

- Hero HP today: `HeroState.health/max_health` = 30 per battle (+`passive_hp` skills in `BattleModifiers.gd` ~L75).
  Add save field `hero_hp` (PERSISTED_FIELDS) written on battle end (`autoloads/scene_manager/BattleVictory.gd`,
  `BattleDefeat.gd`) and read at battle setup. Exclude PvP, puzzles, scripted battles, Spire (own HP rules).
- Regen: WorldScene tick (N HP / in-game minute) when not in battle; full heal at `bed` (`PlayerHome.gd`),
  inns/rest sites (`rest_site` npc_type), town entry. World HUD HP bar (WorldHUD, viewport-relative sizing).
- Defeat at 0 HP → existing game-over/bed respawn routing (`docs/agent/player-home.md`).
- Food: new consumable kind next to potions (`SaveManager.potions`, `GardenDefs.gd`, merchant stock) — eat out of
  combat: regen X HP over Y s, cancelled by engage. Hooks into TID-542 quick slot.
- Early heals: heal spells today are cost 1 `mend`, `dawn_soothing_touch`… mostly branch-gated; add 1–2 neutral
  low-cost heal cards to the starter deck / merchant (`CardRegistry` const preload + `.uid`).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
