# GID-107: Story Arc Expansion — Chapters 1 & 2, Journey Beats & Scripted Tutorial Battles

## Objective

Deepen Chapter 1 with playable journey beats, a real ending, reactive NPC dialogue and Maiteln's travelling presence, then extend the arc with Chapter 2 ("The Road to Larik") — using scripted tutorial battles (fixed deck, deterministic 1-by-1 draw) as the recurring story device that teaches game mechanics.

## Context

Chapter 1's plumbing (flags, ObjectiveTracker, 5 named maps, Isfig rival arc, scrolls/journal) is built, but the chapter has no ending, story beats 2–3 (night camp, rabbit hunt, fire-making) exist only as text in docs/human/story.md, Maiteln never travels with the player, and NPCs don't react to progress. The user approved (2026-07-02) a story pack covering: an enriched Chapter 1, a defined ending, a full flag-gated dialogue table, a Chapter 2 outline with a parents-mystery spine, and scripted tutorial battles starting with the rabbit hunt (fixed 6-card deck, scripted draw order, Maiteln popup guidance). Story content was written into docs/human/story.md with explicit user authorization; the spec's "Chapter 2 out of scope" line was amended. This goal supersedes GID-020/TID-067 (ending scene) and satisfies GID-020's TID-063/TID-066 human TODOs.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-394 | Draft story pack: Ch1 enrichment, ending, dialogue table, Ch2 outline, parents-mystery | agent | done | — |
| TID-395 | Human: approve story pack into story.md + amend spec (Ch2 scope) | human-action | done | TID-394 |
| TID-396 | Scripted battle framework — fixed deck, deterministic draw order, tutorial prompts | agent | pending | — |
| TID-397 | Wilderness journey beats — night camp, rabbit-hunt tutorial battle, fire-making morning | agent | pending | TID-396 |
| TID-398 | Maiteln journey presence — companion avatar on story maps and camps | agent | pending | TID-397 |
| TID-399 | Flag-gated dialogue content pass across all named maps | agent | pending | TID-395 |
| TID-400 | Chapter 1 ending scene + post-council epilogue world reactivity | agent | pending | TID-395 |
| TID-401 | Chapter 2 named maps skeleton (larik, marsax_hold, war-camp dungeon entry) | agent | pending | TID-395 |
| TID-402 | Chapter 2 flags, objectives, beat wiring & scripted ambush battle | agent | pending | TID-400, TID-401 |

## Acceptance Criteria

- [ ] The rabbit-hunt tutorial battle plays with a fixed 6-card deck, opening hand of 1, scripted draw order (ghost → skeleton → ghost → zombie → skeleton → ghoul), and Maiteln tutorial popups; it is impossible to soft-lock and sets `chapter1_camp_night`
- [ ] Night camp and fire-making morning beats trigger on the road after `chapter1_left_madrian`, before Maykalene
- [ ] Maiteln visibly accompanies the player on story maps and camps with objective-keyed ambient lines
- [ ] All NPCs in the flag-gated dialogue table (docs/human/story.md) show correct before/after lines
- [ ] Chapter 1 ending plays via narration overlay at King Eldar after council conditions are met, sets `chapter1_complete`, and returns to a playable epilogue world with war-preparation dialogue
- [ ] Chapter 2 maps (larik, marsax_hold) load, are registered in MapRegistry, and Chapter 2 beats 1–7 are playable through `chapter2_complete` with objectives shown in ObjectiveTracker
- [ ] The Chapter 2 scripted ambush battle reuses the TID-396 framework to introduce spell cards
- [ ] All tests pass headless (`godot --headless --path . -s tests/runner.gd`)
