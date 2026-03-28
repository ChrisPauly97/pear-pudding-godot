# GID-001: Story Flags & Chapter 1 Playthrough

## Objective

Implement the story flag system and wire all Chapter 1 NPC interactions so the full Madrian → Blancogov Temple narrative is playable end-to-end.

## Context

The story maps exist and load correctly, but the narrative layer is incomplete:
- `SaveManager` has no `story_flags` field
- `GameBus` has no `story_flag_set` signal
- `TownspersonNPC.get_dialogue()` returns a static string — there is no flag-gated dialogue
- The `.txt` map format has no syntax for before/after flag dialogue
- Map door connections between the five Chapter 1 maps have not been verified

Without this goal the story mode is a silent collection of isolated maps with no progression. See `docs/human/story.md` for the full story bible and `docs/agent/story-implementation.md` for the technical design.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-001 | Add `story_flags` to SaveManager + `story_flag_set` to GameBus | agent | pending | — |
| TID-002 | Extend TownspersonNPC & WorldMap parser for flag-gated dialogue | agent | pending | TID-001 |
| TID-003 | Wire Chapter 1 NPC story triggers across all 5 maps | agent | pending | TID-002 |
| TID-004 | Verify and fix story map door connectivity | agent | pending | — |

## Acceptance Criteria

- [ ] `SaveManager.story_flags` persists to `save.json` and migrates from older saves (v3)
- [ ] `GameBus.story_flag_set(flag)` signal exists and is emitted whenever a flag is set
- [ ] `NPC x z FLAG:key before || after` syntax is parsed by `WorldMap.load_from_string()`
- [ ] `TownspersonNPC.get_dialogue()` returns the correct line based on flag state
- [ ] Speaking to Maiteln in madrian sets `story_intro_complete`
- [ ] Speaking to Lord Farsyth in farsyth_mansion sets `chapter1_warned_farsyth`
- [ ] Speaking to King Eldar in blancogov_temple sets `chapter1_temple_council`
- [ ] Doors connect: madrian ↔ madrian sub-maps, madrian → maykalene → farsyth_mansion, blancogov → blancogov_temple
- [ ] Player can walk the full Chapter 1 path without hitting a broken door
