# TID-628: Battle banners, attack drags, armor

**Goal:** GID-150
**Type:** agent
**Status:** done

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BattleResultUI built three banners with identical label/shadow/placement code. BattleInput and BattleTargeting both unpacked and validated {"attacker": card} drags. CardInstance and HeroState duplicated armor absorption.

## Plan

See Context.

## Changes Made

`BattleResultUI._make_banner` / `_replace_boss_banner`. `BattleTargeting.drag_attacker` / `ready_attacker` (static). New `game_logic/battle/StatusEffects.gd` with `absorb_armor`.

## Documentation Updates

CLAUDE.md (helper pointers).
