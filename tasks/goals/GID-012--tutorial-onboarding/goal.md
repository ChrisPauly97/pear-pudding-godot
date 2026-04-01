# GID-012: Tutorial / Onboarding for New Players

## Objective

Give new players one-shot contextual tips that teach controls and the battle system without interrupting the flow of play.

## Context

BID-001 identified that new players spawn with no guidance on movement, interaction (E key), inventory (I key), or the TCG battle system. The spec notes that the story intro (Saimtar escaping Madrian with Maiteln) is a natural onboarding moment but is not yet interactive. Option 2 from BID-001 (contextual HUD tips) is lowest scope and fits the existing HUD fade patterns in WorldScene.

Tutorial state is stored in `SaveManager.story_flags` using dedicated `tutorial_*` keys, reusing the existing `set_story_flag` / `get_story_flag` API so no schema changes are needed.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-026 | Proximity-triggered HUD tips in WorldScene | agent | done | — |
| TID-027 | First-battle tutorial overlay in BattleScene | agent | pending | — |

## Acceptance Criteria

- [ ] On first approach to an NPC a tip fades in: "Press E to talk" (Android: "Tap to talk")
- [ ] On first approach to a chest a tip fades in: "Press E to open" (Android: "Tap to open")
- [ ] On first approach to an enemy a tip fades in: "Walk into an enemy to start a battle"
- [ ] On first world entry a tip fades in: "Press I for your inventory" (Android: "Tap the inventory button")
- [ ] Each tip shows exactly once across saves (stored via story_flags)
- [ ] On the player's first battle a dismissible overlay explains drag-to-play and tap-to-attack
- [ ] The battle overlay auto-dismisses after 8 seconds or on first card play
- [ ] All tips respect the Android / desktop control difference (OS.has_feature("android"))
