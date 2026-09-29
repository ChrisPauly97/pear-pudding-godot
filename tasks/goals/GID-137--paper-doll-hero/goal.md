# GID-137: Paper-Doll Player Hero

## Objective

Replace the downloaded player sprite (0x72 `elf_m`) with an original, layered
human hero — clear head, torso, arms and legs — whose look changes with the
gear they equip.

## Context

Raised by the user (2026-09-27): the current hero is a free pack sprite; they
want their own humanoid (human for now) with distinct body parts so equipment
visibly changes the character.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-560 | Layered PaperDoll Renderer & Local Hero | agent | done | — |
| TID-561 | Co-op Avatars Wear Their Gear | agent | done | TID-560 |
| TID-562 | Hero Appearance Picker (skin, hair) | agent | done | TID-560 |
| TID-563 | Art Pass — Helmets & Boots Slots | agent | done | TID-560 |
| TID-564 | Shoulders Slot & Gritty Art Pass | agent | done | TID-560 |
| TID-565 | Smooth Walk, Swing & Jump Animations | agent | done | TID-564 |
| TID-618 | Directional Hero Frames (back view, cast pose) | agent | pending | TID-563 |

## Acceptance Criteria

- [x] Player, battle token and co-op avatars draw from `PaperDoll`, no pack art
- [x] Equipping armour / weapon / off-hand / trinket redraws the hero live
- [x] Every visible item in WeaponRegistry has a visual (enforced by test)
- [x] Shoulders slot with visible pauldrons; grounded, non-cartoon look
- [x] 8-frame walk, weapon swing on engage, jump/fall/land
- [x] Remote co-op avatars show each peer's own gear
- [x] Helmet and boots slots with visible gear (TID-563)
- [x] Player can choose skin tone and hair at New Game
- [x] Tests, gdlint, unsafe-hits, smoke tests clean
