# GID-045: Bestiary Codex

## Objective

A Journal bestiary tab that tracks every enemy type encountered and defeated, revealing stats and lore in tiers, with completion rewards.

## Context

GID-021 is adding enemy variety, but nothing records what you've fought. Staged reveals (seen → defeated → defeated ×3 lore) reward the completionist loop and give the existing Journal and Achievement systems more to do, cheaply.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-170 | Bestiary data: lore fields on EnemyData + encounter/defeat tracking in SaveManager | agent | pending | — |
| TID-171 | Bestiary tab in JournalScene with reveal tiers | agent | pending | TID-170 |
| TID-172 | Completion rewards + achievement hookup | agent | pending | TID-171 |

## Acceptance Criteria

- EnemyData gains a lore_text field (and all bundled enemy .tres files get a written lore blurb); SaveManager tracks per-enemy-id seen and defeated counts with migration
- Starting a battle marks the enemy type seen; winning increments its defeated count — both via existing GameBus battle signals, no new coupling
- JournalScene gains a Bestiary tab: unseen enemies show as "???" silhouettes; seen shows name + deck flavor/stats; defeated ×3 reveals lore text; layout is touch-friendly and viewport-relative
- Defeating every currently-bundled enemy type at least once grants a one-time reward (coins + a rare card) and fires an achievement
- All tests pass headless
