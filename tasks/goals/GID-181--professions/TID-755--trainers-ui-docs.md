# TID-755: Profession trainers, unlocks, Character tab, docs

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-752, TID-753, TID-754

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Ties professions into onboarding and makes progress visible.

## Research Notes

- `game_logic/progression/UnlockLadder.gd`: add `FEAT_ALCHEMY`, `FEAT_COOKING`, `FEAT_CRAFTING` feature rows (level_req, gold cost, trainer, how_to). Gate stations/panels with `save_manager.has_learned(...)` — no separate level checks. New trainers in `TRAINERS` + `TRAINER_NPCS` (Madrian NPCs; authored names → `TownSigns.NAMES`); dispatch in `NpcInteractions.gd`.
- Character screen (`scenes/ui/CharacterScene.gd`): a Professions tab — level, XP bar, known recipe count per profession.
- Optional quest: a starter side quest per profession (`game_logic/quests/SideQuests.gd`).
- Docs: new `docs/agent/professions.md` (Key Features / How It Works / Integrations / Asset Requirements) + a row in the CLAUDE.md docs table; update `starter-zone-and-training.md`, `inventory-and-deck.md`, `save-system.md`.
- Full runner + `scripts/unsafe-hits.sh` + gdlint + world smoke before closing the goal.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
