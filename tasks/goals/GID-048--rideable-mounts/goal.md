# GID-048: Rideable Mounts

## Objective

A purchasable mount — gated to player level 10 — that roughly doubles overworld movement speed, summonable from the HUD, with automatic dismount in battles and interiors.

## Context

The infinite world is big and walk speed is fixed. A mount is both a movement upgrade and a big-ticket coin sink alongside the GID-046 house. Level-gating (level 10+, from the GID-030 XP system) makes it a mid-game milestone purchase.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-179 | Mount framework: MountData, owned/active mount in SaveManager, mounted state + speed multiplier in Player | agent | done | — |
| TID-180 | Stable NPC purchase flow (level 10 gate) + summon/dismiss HUD button (mobile parity) | agent | pending | TID-179 |
| TID-181 | Auto-dismount rules (battle, interiors, dungeons) + mounted sprite/dust visuals | agent | pending | TID-179 |

## Acceptance Criteria

- [ ] MountData defines id, display name, speed multiplier (~2.0) and price; owned_mounts and active_mount persist in SaveManager with migration
- [ ] A stable NPC in madrian sells the first mount (suggested 750 coins, tune against the GID-007/GID-028/GID-046 economy); purchase is refused below player level 10 with the requirement shown ("Requires level 10"), and refused with insufficient coins
- [ ] While mounted, overworld move speed uses the mount's multiplier; a HUD button toggles mount/dismount and works by touch (mobile parity per CLAUDE.md)
- [ ] Entering a battle, named-map interior, or dungeon automatically dismounts; the mount state restores when returning to the overworld
- [ ] Mounted state is visually distinct (mount sprite under/replacing the player sprite + dust particles while moving)
- [ ] All tests pass headless
