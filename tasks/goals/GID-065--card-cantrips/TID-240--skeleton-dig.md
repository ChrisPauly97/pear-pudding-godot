# TID-240: Skeleton Dig — Burial Mounds + Dig Rewards

**Goal:** GID-065
**Type:** agent
**Status:** pending
**Depends On:** TID-238

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Skeleton Dig is the second cantrip — it lets players dig at burial mounds spawned in chunks to unearth coins, cards, and occasional equipment. Mounds are spawn deterministically and only appear in Skeleton-heavy decks (≥4 Skeleton cards), creating opportunistic deck-gated foraging distinct from GID-043 (Treasure Maps, which are directed map-following).

## Research Notes

**Burial mound spawning (InfiniteWorldGen.gd):**
- Follow the existing merchant spawn pattern in `game_logic/world/InfiniteWorldGen.gd` (around the entity-spawn stage).
- Suggest ~10% of chunks roll a mound (seeded/deterministic via world_seed hash).
- Mounds spawn only on TILE_GRASS (not hills, walls, water, etc.) to keep them accessible.
- Spawning is pure and deterministic: same (world_seed, cx, cz) always produces the same mounds, so no per-chunk storage is needed.
- Add a seeded check like: `if hash((world_seed, cx, cz, 42)) % 10 == 0` then roll for mound placement in the grid.
- Append mound data to `ChunkData.entities: Array[Dictionary]` as a new entity type (e.g., `type: "burial_mound"`, `position: Vector3(x, y, z)`, `id: unique_mound_id`).
- Unique ID format: `"mound_%d_%d_%d" % [cx, cz, index_in_chunk]` to ensure mounds can be persisted as "dug" in SaveManager.

**Entity scene: BurialMound.gd / BurialMound.tscn:**
- Model on `scenes/world/entities/Chest.gd` and `Chest.tscn`.
- Visual: a simple mound mesh (heap of dirt/earth) or use a placeholder model.
- Collision: StaticBody3D or Area3D for proximity detection in `WorldScene._check_interactions()`.
- Interaction: when the player enters INTERACT_RANGE (~3 units), show a prompt like "Dig [E]" (mobile: tap the mound).
- Script properties:
  - `mound_id: String` — the unique ID from spawning (e.g., "mound_2_-1_0").
  - `chunk_coords: Vector2i` — (cx, cz) for debugging.
  - `_dug: bool` — tracks whether this specific mound has been looted (synchronized with SaveManager).
  - `_on_interact()` — called when the player activates the mound:
    - Check if already dug (in SaveManager.dug_mounds set or array).
    - If not dug: play dig animation, spawn rewards, add to SaveManager.dug_mounds, emit `GameBus.hud_message_requested`, then disable/hide the mound.
    - If already dug: show a message like "Already dug" and do nothing.

**Rewards from mounds:**
- Each mound yields a small loot table (similar to chest rewards, see `scenes/world/entities/Chest.gd` for pattern):
  - Coins: 10–30 (random, seeded by mound_id so same mound always gives same reward on first dig).
  - Card: ~60% chance, random from CardRegistry (use CardRegistry.random_card() or filter by rarity).
  - Equipment: ~15% chance, random from WeaponRegistry.
  - Essence/crafting material: ~25% chance (e.g., "mana_shard" x 1–3).
- Rewards are not randomized per visit — same mound always yields the same items on first dig (deterministic from seed).

**Persistence:**
- SaveManager new field: `dug_mounds: Array[String]` (stores all mound IDs that have been looted).
- Initialize empty Array[] in migration defaults.
- When a mound is dug, append its id to this array and mark the save dirty.
- When loading a chunk, check each mound's id against dug_mounds and set `_dug = true` if it's in the list.
- BurialMound visibility/interactivity: if _dug is true, hide or disable the mound node (or show a visual state like a filled hole).

**Cantrip eligibility:**
- Skeleton Dig is only available if the player has ≥4 Skeleton cards (checked by CantripManager in TID-238).
- However, mounds exist in all chunks regardless (they're part of the world generation).
- Design decision: either (a) only show the dig prompt if the cantrip is available (gating the action), or (b) allow digging always but restrict rewards if you lack Skeleton cards.
- Suggest (a) for clarity — if you don't have 4 Skeleton cards, the prompt doesn't appear and the mound is just scenery. This encourages deck building and exploration order.

**Mobile parity:**
- Desktop: press E (or rebind via keybindings) when standing near a mound.
- Mobile: tap the mound directly (worldspace touch hit detection in WorldScene._check_interactions()).
- Both paths use the same interaction system, so they're equivalent automatically.

**Integrations:**
- WorldScene._check_interactions() calls `area.get_overlapping_bodies()` each frame to find interaction candidates. BurialMound.gd should have a signal like `interactable_entered / interactable_exited` or set a flag that WorldScene checks.
- Review how Chest.gd and EnemyNPC.gd emit interaction signals (likely via `GameBus.interaction_prompted` or a similar signal).
- HUD shows interaction prompts for all candidates in range, so the mound prompt appears automatically.

**Testing:**
- Headless test: InfiniteWorldGen spawns mounds at expected density (~10% of chunks).
- Headless test: same seed/coords always spawn the same mound with the same reward.
- Integration test (if gameplay test framework exists): dig a mound, verify reward is added, verify SaveManager.dug_mounds is updated, save and load, verify mound is dug on reload.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
