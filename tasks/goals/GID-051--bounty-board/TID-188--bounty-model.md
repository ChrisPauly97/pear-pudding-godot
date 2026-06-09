# TID-188: Bounty Model + Seeded Daily Generation + Save Fields

**Goal:** GID-051
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The data structure and deterministic generation engine. Bounties are pure static functions that take world seed and day index and emit identical sets of three contracts per day, seeding from that pair so they rotate daily but stay stable within a day. Bounty state (offered, accepted, progress, claimed) is persisted in SaveManager alongside the day counter.

## Research Notes

- **New module:** `game_logic/BountyGen.gd`, extends RefCounted, static functions only (no state):
  - `generate_daily(world_seed: int, day_index: int) -> Array[Dictionary]` — returns exactly 3 bounties, each with fields: `{ "id": String, "type": String, "target": String, "count": int, "reward": int }`
  - Seeding: `var rng := RandomNumberGenerator.new(); rng.seed = hash(world_seed, day_index)` (cite hash pattern from DungeonGen or InfiniteWorldGen for consistency)
  - Bounty types in v1: `"defeat_enemy_type"`, `"defeat_in_biome"`, `"open_chests"`
  - For `"defeat_enemy_type"`: target is the enemy type ID (one of `"undead_basic"`, `"undead_horde"`, `"ghoul_pack"`, `"undead_elite"` — cite **autoloads/EnemyRegistry.gd** which has no `get_all_enemy_ids()` yet per v14, so hardcode the 4 type IDs); count 2–4 uniformly random; reward = 40 + `count * 15 + difficulty_tier * 10` where difficulty_tier comes from `EnemyRegistry.get_difficulty_tier(type_id)` (cite line 107–111 of **autoloads/EnemyRegistry.gd**)
  - For `"defeat_in_biome"`: target is a biome ID string (cite **game_logic/world/BiomeDef.gd** lines 3–8: `"grasslands"` (0), `"forest"` (1), `"desert"` (2), `"scorched"` (3), `"mountains"` (4)); count 3–5; reward = 50 + `count * 12 + biome_depth_factor * 15` where depth is 0–4 linearly
  - For `"open_chests"`: count 1–3; reward = `count * 30`
  - ID generation: `"bounty_{day_index}_{type_abbr}_{roll}"` (e.g., `"bounty_42_deftype_0"`)
- **SaveManager fields** (add to **autoloads/SaveManager.gd** and to migration in `_migrate()`):
  - `bounty_day: int = 0` — the day index for which bounties were generated; when `SaveManager.days_elapsed > bounty_day`, a fresh set is generated and bounty_day is updated
  - `offered_bounties: Array[Dictionary] = []` — today's available bounties not yet accepted; each entry is a bounty dict from `generate_daily()` plus initial state fields: `{ ..., "offered_at_day": int }`
  - `active_bounties: Array[Dictionary] = []` — bounties the player accepted; each entry adds: `{ ..., "accepted_at_day": int, "progress": int, "claimed": bool }`
  - Add migration: if save version < vN, set `bounty_day = 0, offered_bounties = [], active_bounties = []`
- **Day counter:** SaveManager already has `days_elapsed: int` (line 45), incremented in `WorldScene._process()` when `_time_of_day` wraps (cite **scenes/world/WorldScene.gd** lines 953–956). Bounties read this field directly.
- **Design decisions:**
  - When a day rolls over (detected by `days_elapsed > bounty_day` on load or at midnight), clear `offered_bounties` (unaccepted offers expire) but keep `active_bounties` in-progress (partially completed bounties carry over until claimed or explicitly abandoned v2).
  - Max 3 active bounties at once; UI rejects accept if 3 are already active.
  - All coin math uses integer division; no rounding errors.
- **Tests (headless):**
  - Determinism: `generate_daily(seed=123, day=5)` always produces the same 3 bounties across runs
  - Rollover: on day boundary, `offered_bounties` clear and are regenerated, `active_bounties` persist
  - Save round-trip: serialize bounties to SaveManager format and deserialize; all fields preserved
  - Reward scaling: verify 4 enemy types produce rewards 40–100 in range, biomes 50–90, chests 30–90

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
