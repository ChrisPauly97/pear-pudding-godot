# GID-020: Story Completion — NPC Dialogue & Chapter 1 Ending

## Objective

Complete flag-gated NPC dialogue (currently ~10% wired) and implement a defined Chapter 1 victory condition and ending scene.

## Context

Story flags persist correctly (GID-001) and NPC dialogue tables exist in story.md, but TownspersonNPC.get_dialogue() returns one static string regardless of flags, and the WorldMap parser does not extract FLAG data. Chapter 1 has no ending trigger. This goal closes those gaps so the story loop is fully playable end-to-end.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-063 | Human: author flag-gated dialogue per NPC per map | human-action | done (via GID-108) | — |
| TID-064 | Implement FLAG map entity syntax in parser | agent | done | — |
| TID-065 | Wire flag-check logic into TownspersonNPC | agent | done | TID-063, TID-064 |
| TID-066 | Human: define Chapter 1 victory condition | human-action | done (via GID-108) | — |
| TID-067 | Implement Chapter 1 ending scene/trigger | agent | superseded by GID-108/TID-405 | TID-066 |

> **2026-07-02:** The GID-108 story pack (user-approved) filled TID-063's dialogue table and
> TID-066's victory condition directly in `docs/human/story.md` / `specification.md`. The
> remaining implementation work moved to GID-108: dialogue application → TID-404, ending
> scene → TID-405. This goal's open acceptance criteria are carried by those tasks.

## Acceptance Criteria

- [x] NPC dialogue in all 5 named maps changes correctly based on story flags (GID-108 / TID-404;
      King Eldar/Queen/Scargroth in blancogov_temple via GID-108 / TID-405)
- [x] FLAG directive in map files is parsed and passed to TownspersonNPC nodes (superseded by the
      GID-017 `.tres` migration — `MapNpc.flag_key`/`after_dialogue` fields, same effect)
- [x] Chapter 1 victory condition is triggered at the defined point (GID-108 / TID-405 —
      `WorldScene._handle_king_eldar_interaction`/`_trigger_chapter1_ending`)
- [x] An ending overlay/scene plays and sets the chapter1_complete flag (GID-108 / TID-405 —
      `scenes/ui/ChapterEndingOverlay.gd`)
- [ ] All tests pass headless — not run in this sandbox (no Godot binary; see TID-405 Changes
      Made); recommended before merge

All engineering criteria are satisfied via GID-108 (TID-404 + TID-405). This goal is resolved
pending a headless test confirmation.
