# GID-142: Spire → Biome Rifts

## Objective

Turn the Endless Spire into D3-style rifts: one rift per biome, each with its own tier ladder you push higher with your own deck, where progression rewards come from one-time rift quests rather than repeatable runs.

## Context

User (2026-09-28): "spire works like d3 rifts where you run it, get xp and reach for higher levels, rewards etc." Design
answers:
- **Floors, no timer.** Pick a tier (up to best + 1); tier scales enemy level; clear the floors to complete the tier and
  unlock the next.
- **Own deck + draft boons.** Fight with your real deck; between floors pick 1 of 3 temporary run-only boons.
- **No XP spam.** "You can't just spam rifts to level up." Reward the player via quests to reach a certain tier; more
  quests later to rift in different biomes with different enemy types. **Each rift is separate and tracks its own tier.**

Today the Spire is a single roguelike draft climb (`SaveSpire`, `SpireFloorGen`, `SpireDraft`, `SpireDraftScene`) with a
fixed starter deck, one enemy per floor, boss every 7 floors, and 5 coins per floor. It unlocks at L15 in GID-141's ladder.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-597 | Rift Model — Per-Biome Rifts & Tier Ladders | agent | done | — |
| TID-598 | Own Deck + Draft Boons | agent | done | TID-597 |
| TID-599 | Anti-Spam Rewards & Rift Quests | agent | done | TID-597, TID-533 |
| TID-600 | Rift Entrances in Each Biome | agent | done | TID-597, TID-589 |
| TID-601 | Co-op Rifts & Per-Rift Leaderboard | agent | pending | TID-597 |
| TID-602 | Docs | agent | pending | TID-599, TID-600, TID-601 |

## Acceptance Criteria

- [ ] Five rifts (one per biome), each with its own best tier and enemy pool; tier selection capped at best + 1.
- [ ] Runs use the player's own deck; boons between floors are temporary and vanish at run end.
- [ ] Repeating a cleared tier grants no XP; XP comes from first clears and one-time rift quests.
- [ ] Rift quests exist for the first tiers of each rift; the first one is given at L15 training.
- [ ] Existing saves keep their Spire record (migrated) and achievements/trophies still award.
- [ ] Co-op rifts and the PvE leaderboard work per rift + tier.
- [ ] Tests, gdlint, unsafe-hits and scene smoke tests pass.
