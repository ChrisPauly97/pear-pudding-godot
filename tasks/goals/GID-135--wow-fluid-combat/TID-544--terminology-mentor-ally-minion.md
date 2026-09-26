# TID-544: Terminology — Mentor, Ally, Minion

**Goal:** GID-135
**Type:** agent
**Status:** pending
**Depends On:** TID-540

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User decision (TID-540): Maiteln-style passive helper = **Mentor** (one at a time); player creature cards = **Allies**; enemy creatures = **minions**. Rename user-facing text first.

## Research Notes

- "Companion" UI text: `scenes/ui/CharacterScene.gd` (~L112 header, L175/180 button, L220 picker title,
  L272 locked text); battle Effects panel entry (`BattleArena.collect_effect_entries`); tutorials/popups
  (`game_logic/TutorialRegistry.gd`); docs (`docs/agent/battle-system.md` companion sections).
- Card UI: player-side creature card class label → "Ally"; enemy board → "minion". CardData `card_class`
  stays `"minion"` internally (save/card data compatibility) — change display strings only.
- Code identifiers (`CompanionRegistry`, `equipped_companion` save field) stay unless a cheap rename; a save-field
  rename needs `SaveMigrations.gd`. Prefer display-only this task.
- Grep: `grep -rn "Companion\|companion" --include=*.gd scenes game_logic` for strings.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
