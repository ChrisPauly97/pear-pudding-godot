# GID-013: Story Narration Scrolls

## Objective

Let players find lore scrolls in the world that auto-play background audio narration on pickup, are logged in a journal overlay for later review, and are tracked for a collection achievement.

## Context

Inspired by Diablo 3 lore books: scrolls are scattered through named maps and the infinite world. Picking one up triggers non-blocking audio narration — the player keeps moving while the story plays. Active NPC story-beat dialogue suppresses narration to prevent overlap. All found scrolls are accessible in a Journal overlay (J key) with lore text and a replay button. `SaveManager` tracks `collected_scrolls` for achievement checks.

Audio files use the existing graceful no-op pattern (silent if files absent), so the full system ships and functions without audio assets — files can be added later.

See BID-002 for the related spec update needed ("Voice acting" currently listed as out of scope).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-028 | Scroll registry, SaveManager fields, GameBus signal | agent | done | — |
| TID-029 | StoryScroll world entity + WorldMap SCROLL directive + named map placements | agent | done | TID-028 |
| TID-030 | Narration audio channel (AudioManager extension + story-beat suppression) | agent | done | TID-028 |
| TID-031 | Journal / Codex UI overlay | agent | done | TID-028 |
| TID-032 | Infinite world scroll placement via InfiniteWorldGen | agent | done | TID-029 |
| TID-033 | HUD pickup notification + achievement milestone tracking + doc updates | agent | pending | TID-028, TID-029 |

## Acceptance Criteria

- [ ] Walking near a StoryScroll in a named map and pressing E collects it and starts narration audio
- [ ] Narration plays in the background — player movement is unrestricted
- [ ] If NPC dialogue is active when a scroll is collected, narration is deferred or suppressed
- [ ] Collected scrolls persist across save/load
- [ ] J key opens the Journal overlay listing all collected scrolls with title and lore text
- [ ] Journal has a replay button that re-plays the narration audio
- [ ] Scrolls appear in the infinite world at seed-deterministic positions
- [ ] Already-collected scrolls do not re-spawn in the world
- [ ] Collecting all scrolls emits `GameBus.all_scrolls_collected` (achievement hook)
- [ ] All features degrade gracefully when audio files are absent
