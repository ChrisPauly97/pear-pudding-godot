# GID-020: Story Completion — NPC Dialogue & Chapter 1 Ending

## Objective

Complete flag-gated NPC dialogue (currently ~10% wired) and implement a defined Chapter 1 victory condition and ending scene.

## Context

Story flags persist correctly (GID-001) and NPC dialogue tables exist in story.md, but TownspersonNPC.get_dialogue() returns one static string regardless of flags, and the WorldMap parser does not extract FLAG data. Chapter 1 has no ending trigger. This goal closes those gaps so the story loop is fully playable end-to-end.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-063 | Human: author flag-gated dialogue per NPC per map | human-action | pending | — |
| TID-064 | Implement FLAG map entity syntax in parser | agent | pending | — |
| TID-065 | Wire flag-check logic into TownspersonNPC | agent | pending | TID-063, TID-064 |
| TID-066 | Human: define Chapter 1 victory condition | human-action | pending | — |
| TID-067 | Implement Chapter 1 ending scene/trigger | agent | pending | TID-066 |

## Acceptance Criteria

- [ ] NPC dialogue in all 5 named maps changes correctly based on story flags
- [ ] FLAG directive in map files is parsed and passed to TownspersonNPC nodes
- [ ] Chapter 1 victory condition is triggered at the defined point
- [ ] An ending overlay/scene plays and sets the chapter1_complete flag
- [ ] All tests pass headless
