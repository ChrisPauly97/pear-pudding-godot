# GID-066: The Creeping Blight — Corruption Territory & Cleansing

## Objective

Persistent Martarquas corruption spreads chunk-by-chunk from seeded Blight Hearts as in-game days pass; players cleanse hearts via boss battles to permanently purify regions and earn redemption points.

## Context

The infinite map currently feels static and timeless. The Creeping Blight makes it feel alive and contested: Martarquas corruption visibly spreads from fixed positions each day, creating urgency and territorial gameplay. Blighted regions feature visible tinting, ambience changes, and enemy buffs, giving players a reason to engage with the corruption/redemption currency system (SaveManager fields already exist). Cleansing a Blight Heart is a major challenge rewarding significant progression. This ties directly to the story (Martarquas antagonists) and gives the infinite world a dynamic, evolving state players can influence.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-241 | Blight State Model — Seeded Hearts, Day-Tick Spread, Persistence | agent | done | — |
| TID-242 | Blight Rendering — Terrain Tint, Ambience, Enemy Buff | agent | done | TID-241 |
| TID-243 | Blight Heart Entity — Cleanse Battle, Purification, Rewards | agent | done | TID-242 |

## Acceptance Criteria

- [ ] Blight spreads deterministically from seeded Blight Hearts on each in-game day tick.
- [ ] Spread persists across save/load; cleansed hearts remain purified permanently.
- [ ] Blighted chunks have a visible tint (dark purple desaturation) and possibly mood/ambience changes.
- [ ] Enemies in blighted chunks are buffed (e.g., +HP or +starting mana) when battles occur there.
- [ ] Cleansing a Blight Heart via boss battle awards redemption points and purifies the region permanently.
- [ ] Blight state is a pure function of (world_seed, SaveManager.days_elapsed, cleansed_set) — no per-chunk storage needed.
- [ ] All tests pass headless.
