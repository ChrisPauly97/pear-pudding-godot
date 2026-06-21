# GID-081: Coherent HUD & Unified In-Game Navigation

## Objective

Replace the scattered overworld HUD buttons and the four disconnected character-screen modals with a decluttered HUD and a single tabbed Menu Hub that lets players move freely between Deck/Bag, Character & Equipment, Skills, and Journal.

## Context

The overworld HUD has accumulated buttons in every corner (`WorldScene.gd:342–435`): a `Menu` + `II` pause pair top-left, a five-button stack (Inventory/Journal/Character/Skills/Mount) under the minimap, plus loose cantrip buttons. The four player-facing screens (Inventory, Character, Skills, Journal) each open as a standalone `BaseOverlay` via a `GameBus.*_requested` signal and a dedicated `SceneManager` state, and the only way out of each is to close back to the world — there is no cross-navigation. This goal introduces a shared tabbed shell so the screens are connected, and reorganizes the HUD so system controls and contextual actions are grouped naturally. Aligns with the overlay framework introduced in GID-073 and the mobile/desktop parity rule in CLAUDE.md.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-296 | Menu Hub navigation shell + SceneManager routing (page contract; wire Inventory/Deck as first tab) | agent | done | — |
| TID-297 | Migrate Character/Equipment, Skills, and Journal into hub tabs with cross-navigation | agent | done | TID-296 |
| TID-298 | HUD declutter: merge top-left system controls, single Menu/Bag entry, regroup cantrip + Mount action cluster | agent | done | TID-296 |
| TID-299 | Unified key bindings, in-hub tab cycling, Escape/back semantics, mobile tap parity + docs/test pass | agent | done | TID-296, TID-297, TID-298 |

## Acceptance Criteria

- [x] A single Menu Hub overlay hosts Deck/Bag, Character, Skills, and Journal as switchable tabs with a persistent tab bar
- [x] From any tab the player can switch to any other tab without returning to the world
- [x] `SceneManager` exposes one `open_menu_hub(tab)` entry point and a single hub state replacing the separate INVENTORY/CHARACTER/SKILL_TREE/JOURNAL states
- [x] All existing functionality of the four screens (deck building, equipment slots, skill tree interaction, journal sub-tabs) is preserved
- [x] The overworld HUD top-left is a single system/pause control; the five-button right stack is replaced by a single Menu/Bag entry that opens the hub
- [x] Contextual action buttons (cantrips, Mount) are grouped into one coherent cluster and only shown when relevant
- [x] Every navigation key (open hub / open a tab / cycle tabs / back) has a mobile tap equivalent; all controls are viewport-relative
- [x] `docs/agent/ui-and-scene-management.md` documents the Menu Hub, the page contract, the new HUD layout, and key bindings
- [x] All tests pass headless (1129 pass, 12 pre-existing failures, 0 regressions)
