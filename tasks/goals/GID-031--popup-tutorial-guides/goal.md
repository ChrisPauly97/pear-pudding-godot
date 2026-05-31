# GID-031: Popup Tutorial Guide System

## Objective

Build a reusable, data-driven popup tutorial overlay that can explain any game system (skill trees, currencies, card rarity, etc.) on first encounter — and is trivially extensible for future guides.

## Context

The game already has one-shot HUD tip labels and a first-battle overlay (GID-012), but these are hardcoded and can't explain complex systems. Players open the skill tree or see "Essence" for the first time with no context. This goal adds a proper popup guide layer: a `TutorialRegistry` holds all guide content, a `TutorialPopup` scene renders it, and `GameBus` routes trigger signals so any system can fire a guide without coupling to the UI.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-116 | TutorialPopup scene — reusable overlay | agent | done | — |
| TID-117 | TutorialRegistry — data store for popup content | agent | pending | TID-116 |
| TID-118 | Wire first-time triggers (skill tree, coins, essence, mana, card rarity) | agent | pending | TID-117 |

## Acceptance Criteria

- [ ] Opening the skill tree for the first time shows a popup explaining it
- [ ] First coin pickup shows a popup explaining coins
- [ ] First essence gain shows a popup explaining essence
- [ ] Each popup is shown exactly once (SaveManager flag persists)
- [ ] Adding a new popup requires only one entry in TutorialRegistry — no UI code changes
- [ ] Popup works on both desktop (keyboard dismiss) and mobile (tap "Got it")
