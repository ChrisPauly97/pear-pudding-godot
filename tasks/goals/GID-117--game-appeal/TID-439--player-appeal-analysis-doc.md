# TID-439: Player Appeal Analysis Doc (docs/agent/game-appeal.md)

**Goal:** GID-117
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The direct, durable answer to "why would people play this game?" No such analysis exists
anywhere in the repo — the spec lists features, not appeal. This doc becomes the reference
for TID-440's audit checklist, TID-442's pitch draft, and any future store-page or
marketing copy.

## Research Notes

Write `docs/agent/game-appeal.md` and add a row to the index tables in
`docs/agent/docsplan.md` and `CLAUDE.md` (the docs/agent table at the bottom).

Structure it around these findings (verify/refine against the linked docs, don't re-research
from scratch):

**Signature hooks (world ↔ card fusion — the differentiators):**
- Soulbinding (GID-061, `docs/agent/soulbinding.md`) — every enemy type is capturable as a
  card via per-battle capture conditions (`game_logic/battle/CaptureTracker.gd`:
  spell_final_blow, hero_hp_at_most, no_minion_hero_attacks, win_by_turn). Reveal UI in
  `scenes/battle/BattleResultUI.gd::show_soulbind()`.
- Card Cantrips (GID-065, `docs/agent/card-cantrips.md`) — deck composition unlocks overworld
  abilities: Ghost Phase (wall pass), Skeleton Dig (burial mounds, needs ≥4 Skeleton-family
  cards in deck).
- Battlefield Resonance (GID-059) — biome/location of the overworld fight buffs matching
  cards in the battle.
- Veteran Cards (GID-060, `game_logic/VeterancyUtil.gd`) — per-instance battle history.
- Ley Lines (GID-068), Blight (GID-066), Night Hunts (GID-055) — world state that feeds
  battle state.

**Multiplayer breadth (rare at this scope on mobile):** 4-player co-op with joint battles on
a shared square battlefield (GID-099/100), PvP duels, draft duels, tournaments, spectator
wagers (GID-104), guildhall/co-op Spire (GID-106). See `docs/agent/multiplayer-coop.md`.

**Comfort/collector loop:** story tone per `docs/human/story.md` (Hobbit/Redwall), player
home & trophies (GID-046), garden & potions (GID-056), mounts (GID-048), bestiary (GID-045),
treasure maps (GID-043), card packs with pity counter (GID-050).

**Sections to write:**
1. One-paragraph thesis (the "why").
2. Player motivation mapping — which motivations the game serves (collector/completionist,
   explorer, tactician, social/co-op, narrative-cozy) and which shipped systems serve each.
3. Target player profiles (2–3 concrete personas, primary platform Android).
4. Differentiation vs. genre neighbors: Hearthstone-likes (no world), Zelda-likes (no deck),
   monster-collectors (Pokémon-likes — closest analog for soulbinding; state what's different).
5. Honest weaknesses — hooks invisible in first session (feeds TID-440/441); no pitch
   (feeds TID-442); 4 base card families may read as thin at first glance despite 46+
   templates; pixel-art placeholder feel in places (see GID-089 for what's done).

**Constraints:** agent doc — exhaustive and current per CLAUDE.md. Every appeal claim must
cite the GID/system that backs it. No code changes in this task.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
