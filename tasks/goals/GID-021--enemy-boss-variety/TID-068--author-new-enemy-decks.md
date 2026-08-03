# TID-068: Human — Author New Enemy Decks and Drop Pools

**Goal:** GID-021
**Type:** human-action
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Type override note

Applied directly by the agent with the human's explicit, in-conversation
permission to edit `docs/human/` for this batch of pending human-action
tasks (2026-08-03) — the normal flow (agent presents options, human
authors/confirms) was waived for this specific request.

## Context

The agent needs to know each new enemy's deck composition and drop pool before creating .tres files. The human defines these in story.md so they fit the narrative and desired difficulty curve.

## What the Human Needs to Do

Open `docs/human/story.md` and fill in the **New Enemy Types** table (added during goal creation). For each of the 6 new enemies:

1. **Deck:** List card IDs and how many copies (e.g. `ghost x3, skeleton x2, ash x1`). Use existing card IDs from `data/cards/` — or propose new card names for GID-018 to add.
2. **Drop pool:** List card IDs this enemy can drop as rewards (1–4 cards in the pool; player gets 1 on defeat).
3. **Coin reward:** How many coins dropping this enemy gives.

Also fill in the **Boss Enemy Types** table for the 2 bosses.

**Existing card IDs for reference:**
- Minions: ghost, skeleton, zombie, ghoul
- Ember spells: spark, flicker, ember, scorch
- Ash spells: ash, brittle, char, alight
- Special: dagger_throw
- Dawn cards (GID-018): dawn_acolyte, dawn_paladin, mend, restore, bulwark, rally, radiance, blessed_light
- Dusk cards (GID-018): dusk_wraith, dusk_vampire, drain, wither, siphon, shadow_bolt, soul_rend, dark_pact

**Note:** GID-018 Dawn/Dusk cards may not exist yet when this is being filled in. It is fine to reference them — TID-069 depends on TID-068, and GID-018 runs in parallel.

## When Done

Notify the agent. TID-069 and TID-071 can then proceed.

## Plan

_N/A — human action._

## Changes Made

- `docs/human/story.md`: filled in the "New Enemy Types" table (6 enemies:
  wraith, forest_shade, sand_stalker, scorched_revenant, mountain_troll,
  stone_golem) and "Boss Enemy Types" table (2 bosses: hollow_steward at
  farsyth_mansion, martarquas_vanguard at blancogov_temple) with decks, drop
  pools, and (for the bosses) special mechanics — using only existing
  `data/cards/` IDs, all verified present. Deck design followed each
  enemy's archetype from `specification.md`'s "Planned Enemy Types" table
  (fast/low-HP, evasive+draw, rush, burn/AoE, high-HP/slow, boss-tier tank);
  the two story bosses tie into existing narrative hooks (the Farsyth
  mansion "strange things" hint, the Traitor mystery, and a Chapter 1
  climax fight distinct from Chapter 2's `martarquas_warleader`).

## Documentation Updates

_N/A — human-owned doc; unblocks TID-069 (registry entries) and TID-071
(boss map placement), both agent tasks._
