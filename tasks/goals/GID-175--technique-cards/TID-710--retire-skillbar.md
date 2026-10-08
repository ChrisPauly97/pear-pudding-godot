# TID-710: Retire SkillBar dependents + docs

**Goal:** GID-175
**Type:** agent
**Status:** pending
**Depends On:** TID-708, TID-709

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Remove the last references to the fixed bar and update the docs.

## Research Notes

- References (grep `SkillBar|skill_bar`): `scenes/ui/SkillBarScene.gd` (loadout picker, delete), `scenes/ui/MenuHubScene.gd` (entry), `MentorBarks.gd` / `BarkRules.gd` (Kick/Strike barks → hand cards), `CombatOnboarding.gd` / `BattleOnboarding.gd` (first-time tips), `FightStats.gd` (post-fight coaching), tests `test_skill_bar`, `test_combat_onboarding`, `test_combat_momentum`, `test_unlock_ladder`.
- Delete `game_logic/battle/SkillBar.gd` once nothing preloads it (or reduce it to a data table read by the cards).
- Docs: combat-model.md, ui-and-scene-management.md (SkillBarScene), enemies-and-npcs.md (trainer), starter-zone-and-training.md, the CLAUDE.md BattleRealtime row (mentions `BattleSkillBar.gd` / `SkillBar.gd`).
- Full suite: no `SCRIPT ERROR` in the log.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
