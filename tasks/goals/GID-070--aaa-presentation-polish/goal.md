# GID-070: AAA Presentation & Platform Polish

## Objective

Close the remaining presentation and platform gaps — scene transitions, overworld pause, save slots, gamepad support, menu presentation, accessibility options, and ambient audio — that no existing goal covers.

## Context

A codebase audit (June 2026) compared the game against AAA presentation staples, excluding everything already covered by GID-001…GID-069. Seven gaps remained: SceneManager hard-cuts between scenes with no fade; the overworld has no pause menu (only battles do); there is a single hardcoded save file with no slots; the input map is keyboard/touch only with zero gamepad bindings; the main menu is a static title with no splash or version label; there are no accessibility/comfort options (screen-shake toggle, text scale, haptics); and biomes have no ambient soundscapes. Spec reference: "A complete, shippable game on Android (primary platform) and desktop" (docs/human/specification.md — Goals). Ambient audio is SFX, not music, so it stays within the spec's "no music" out-of-scope line (see BID-002 for the existing spec tension).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-255 | Scene Transition Fades | agent | done | — |
| TID-256 | Overworld Pause Menu | agent | done | — |
| TID-257 | Save Slots & Slot Select UI | agent | done | — |
| TID-258 | Gamepad / Controller Support | agent | done | — |
| TID-259 | Main Menu & Title Presentation | agent | done | TID-257 |
| TID-260 | Accessibility & Comfort Settings | agent | done | — |
| TID-261 | Ambient Biome Soundscapes | agent | done | — |

## Acceptance Criteria

- [ ] Every scene change (world ↔ battle ↔ inventory ↔ menus) fades out and in; no hard cuts remain
- [ ] ESC (desktop) and a HUD button (mobile) open a pause overlay in the overworld with Resume / Settings / Save & Quit
- [ ] Three save slots with a slot-select UI; existing single saves migrate to slot 1 without data loss
- [ ] The game is fully playable on desktop with a gamepad: movement, interact, UI focus navigation
- [ ] Main menu shows an animated title treatment, version label, and polished layout
- [ ] Settings include screen-shake toggle, text scale, and haptics toggle; haptics fire on Android for key actions
- [ ] Each of the 5 biomes has a looping ambient soundscape that crossfades on biome change and respects the SFX volume setting
