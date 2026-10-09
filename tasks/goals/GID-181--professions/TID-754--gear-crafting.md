# TID-754: Crafting: gear from ore and hide

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-749, TID-750, TID-751

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Lets the player make equipment, with quality that scales with crafting skill.

## Research Notes

- Equipment: `autoloads/WeaponRegistry.gd`, `data/WeaponData.gd`, slots in SaveManager (`# Non-weapon equipment slots`), upgrades in `game_logic/UpgradeDefs.gd` / `BlacksmithScene.gd`, and rolls in `game_logic/items/GearRolls.gd` (`roll(tier, level, rng)`, saved in `gear_rolls`, keeping the better roll).
- Crafted gear output: a recipe names an existing weapon/equipment id; the roll comes from a crafting-specific weight table: skill level → tier, item level = the recipe's level. It competes with drops but caps at `epic` (legendary stays drop-only).
- Grant through the same path drops use, so `GameBus.equipment_changed` fires and co-op appearance updates (`CoopAppearance`).
- The workbench is a station (TID-751); the Blacksmith keeps upgrades.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
