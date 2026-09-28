# GID-136: WoW-Style RPG Loop

## Objective

A persistent-world RPG loop: town NPCs give quests with tracked objectives, zones have level ranges, trainers teach skill cards, and gear improves as you explore.

## Context

Raised by the user (2026-09-26): towns, NPCs with asks, tracked objectives like bounties, levelling, gear, money and skills-as-cards. XP, levels, coins, gear slots and bounties already exist; this goal ties them into quest-driven progression.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-533 | Quest Data & Registry (also prerequisite of GID-141) | agent | done | — |
| TID-534 | Quest-Giver NPCs & First Madrian Chain (chain content delivered by GID-141 / TID-592) | agent | done | TID-533 |
| TID-535 | Quest Log & On-Screen Tracker | agent | superseded | TID-533 |
| TID-536 | Zone Level Ranges & Enemy Levels (also prerequisite of GID-141) | agent | done | — |
| TID-537 | Class Trainers & Skill Cards | agent | done | TID-536, TID-540 |
| TID-538 | Gear Rarity, Item Level & Quest Reward Choice | agent | pending | TID-533, TID-536 |
| TID-542 | Consumables — Inventory Use & D3-Style Quick Slot | agent | pending | — |
| TID-543 | Persistent Hero HP & Healing (Food, Early Heals) | agent | pending | TID-540, TID-545 |
| TID-556 | Skill Bar Loadout Picker | agent | done | TID-537 |
| TID-557 | Training Dummy | agent | done | TID-537 |
| TID-539 | Spec Update — RPG Loop, XP, WoW Inspiration, Combat Pivot | human-action | pending | — |

## Acceptance Criteria

- [ ] A playable Madrian quest chain with ! / ? markers, quest log and HUD tracker
- [ ] Enemies show levels; XP and difficulty scale with zone level
- [ ] Skill cards learned from trainers are usable in battle
- [ ] Gear drops with rarity and item level; quest turn-in offers a gear choice
- [ ] Consumables usable from the inventory
- [ ] Spec amendments drafted and confirmed by the user
- [ ] Tests, gdlint, unsafe-hits, smoke tests clean
