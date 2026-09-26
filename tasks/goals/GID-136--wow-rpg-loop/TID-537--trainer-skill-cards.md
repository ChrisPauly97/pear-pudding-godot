# TID-537: Class Trainers & Skill Cards

**Goal:** GID-136
**Type:** agent
**Status:** pending
**Depends On:** TID-536, TID-540

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User: skill cards are the things you use in battle. Trainer NPCs in towns teach skill cards for coins at level thresholds; ranks upgrade them. Final shape follows the TID-540 combat model.

## Research Notes

- Current skills: `data/SkillData.gd` (skill_type passive/active, effect_type, magic_branch, prerequisites);
  `autoloads/SkillRegistry.gd`; tree UI `scenes/ui/SkillTreeScene.gd`; active skill → hero power in
  `BattleConsumables.gd`. Magic types/branches from `game_logic/MagicTypes.gd` (never re-list branches).
- Plan direction: active skills become spell cards (CardData, branch-owned — `test_magic_types` checks card
  magic_type vs branch) learned at a `trainer` npc_type; passives stay in the tree. Deck always includes learned
  skill cards (or a skill bar — per TID-540). Save: `learned_skill_cards` {id: rank}; migration of existing
  `unlocked_skills` actives in `SaveMigrations.gd`.

- **TID-540 decided Option A** — read `docs/agent/combat-model.md` (Decisions section) first. Use the
  Mentor / Ally / Minion terminology.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
