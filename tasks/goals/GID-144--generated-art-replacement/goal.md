# GID-144: Generated Art Replacement

## Objective

Replace every remaining third-party sprite with an original generated one (roadmap in
`docs/agent/art-sprites.md`, batches B0–B4), so CREDITS lists no third-party art besides fonts and music.

## Context

User (2026-09-29): "long term generate sprites for everything that's currently 3rd party too", then "go ahead with
the art roadmap". Backlog BID-068..072 (from GID-143 / TID-607). Generators: `tools/generate_characters.py`
(characters), `tools/generate_sprites.py` (props), palette `tools/pixel_palette.py`.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-609 | B0 — Delete Unreferenced Art | agent | done | — |
| TID-610 | B1 — Generated World Characters | agent | done | TID-609 |
| TID-611 | B2 — Generated Card Art & Spell Runes | agent | done | TID-610 |
| TID-612 | B3 — Generated Chest, Door, Mimic & Horse | agent | done | TID-610 |
| TID-613 | B4 — Original HUD Icons | agent | done | — |

## Acceptance Criteria

- [x] No unreferenced art ships (BID-068).
- [x] Every world character, card portrait, rune, chest/door/mimic/horse and HUD icon is generated in-house.
- [x] CREDITS.md and `art-sprites.md` list no third-party sprite sources.
- [x] Tests, smokes, gdlint, unsafe-hits pass; captures checked for each batch.
