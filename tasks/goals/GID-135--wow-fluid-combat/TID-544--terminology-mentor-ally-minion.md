# TID-544: Terminology — Mentor, Ally, Minion

**Goal:** GID-135
**Type:** agent
**Status:** done
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

Display text only (code identifiers, `card_class = "minion"` and the `equipped_companion`
save field stay). Mentor = Maiteln-style helper, Ally = the player's creature cards,
minion = enemy creatures.

## Changes Made

- CharacterScene: Companion → Mentor (header, slot button, picker, first-equip toast).
- BattleArena effects panel: "Mentor: <name>".
- UnlockLadder: Maiteln lesson says mentor; "Summoning Minions" → "Summoning Allies".
- SideQuests barrow quest, Rift "Keen Edge" boon, first-battle tutorial: allies.
- SpellEffectLabels: friendly-minion wording → ally/allies (enemy minions unchanged).
- Inventory filter + card kind labels (InventoryScene, CraftPanel): Minion → Ally.
- Card descriptions "your minions" → "your allies" (5 cards).
- Left alone: co-op "ally" meaning a teammate (`ally_revive`), BattlefieldRules
  (applies to both sides), code/docs identifiers.

## Documentation Updates

- None beyond this file: `combat-model.md` already defines the terms.
