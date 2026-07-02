# TID-385: Draft Duels — Sealed-Deck PvP

**Goal:** GID-104
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

PvP today pits full collections against each other, so a veteran always outguns a new player. A sealed/draft format where both duelists build decks live from identical seeded card pools is the fairest possible PvP. Draft duels let any two connected players challenge each other into a restricted format with zero collection advantage—the only skill that matters is deck-building choices in the pick flow. This reuses two shipped systems: the Endless Spire draft UI/pick mechanics (GID-038) for the 1-of-3 pick flow, and the Card Packs seeded roll logic (GID-050, `CardPackRegistry` + `roll_with_pity`) for generating the identical pools. Entry flows through the existing challenge handshake—`request_battle`/`respond_battle` via `NetSync` (mirroring how `ranked` is threaded)—with a new `draft` boolean flag indicating sealed-deck mode. Drafted decks are transient in-memory only; they are never written to `owned_cards` or persisted, so `SaveManager` state is untouched.

Both peers derive the same seeded card pool deterministically from a shared seed (either the host picks the seed before picks begin, or the host validates peer picks after-the-fact). The host then orchestrates the draft picking via a small RPC pair (similar to the loot-roll prompt pattern from bounty rewards or the pack-opening ceremony UI). Alternatively, both peers can fully deterministically draft offline from the shared seed with pick intents relayed to the host for conflict resolution. The first approach matches the social experience of watching a peer pick live on the map overlay; the second is lower-latency. The decision is made during the Plan phase. All code is guarded by `NetworkManager.is_active()` so single-player mode is untouched.

## Research Notes

**Existing patterns:**
- Challenge handshake: `NetSync.request_battle(opponent_idx, ante_coins, ranked)` / `respond_battle(accept)` in `scenes/multiplayer/NetSync.gd`; the `ranked` flag is already threaded through to `SceneManager.enter_pvp_battle(local_idx, opponent_deck, ante_coins, ranked)` and then to `BattleScene._init_game_state_coop(ranked=False)` and `GameState.from_dict()` which applies the `Ranked` rule set.
- Wire format: pure helpers in `game_logic/net/BattleNetProtocol.gd` (sealed, no scene dependencies); for draft, add a new pair: `encode_draft_seed(seed: int) -> PackedByteArray` and `decode_draft_seed(bytes: PackedByteArray) -> int`, or extend the existing `BattleNetProtocol` dictionary format with a `"draft_seed"` field if the seed is part of the battle state mirror.
- Seeded roll logic: `CardPackRegistry.roll_with_pity(tier: String, seed: int, pity_count: int) -> SkillData` is pure, deterministic, and reusable. Generating a sealed pool is rolling N cards with a seeded RNG stream (similar to how `GID-050` generates a pack).
- Draft UI: Endless Spire (`scenes/draft/DraftScene.gd`) implements the full 1-of-3 pick flow, showing 3 card options, handling pick submission, and managing a cumulative drafted deck. This can be reused directly or a variant can inherit from it.
- Duel entry: `SceneManager.enter_pvp_battle(local_idx, opponent_deck, ante_coins, ranked=False)` currently expects the opponent deck as `Array[String]` (card IDs). For draft duels, the opponent deck is built live during the draft, so the entry flow is: both peers draft → both submit their final decks → host validates or relays decks → host calls `enter_pvp_battle` with the drafts.
- Wagered duels: the `ante_coins` pattern in TID-362 deducts `SaveManager.add_coins(-ante)` on challenge accept via `_on_pvp_challenge_accepted_coop`. Draft duels inherit this: the same ante escrow applies.

**CLAUDE.md invariants:**
- Preload + UID: if new `.tres` draft-related resources are created (e.g. a dedicated DraftConfig), declare `const _DRAFT_CONFIG := preload("res://assets/...")` in the calling scene and generate a `.uid` sidecar.
- Headless import: after any `.gd` edit, run `godot --headless --editor --quit 2>&1 | grep -iE "Parse Error|Compile Error|Failed to load script"` — must be empty.
- Mobile parity: if the draft UI adds new interactive elements, ensure they have both keyboard (Enter to confirm pick) and touch (tap pick option) affordances.
- NetworkManager guard: wrap all draft duel logic in `if NetworkManager.is_active():` so single-player mode is untouched.

**Files to examine:**
- `scenes/multiplayer/NetSync.gd` — `request_battle` / `respond_battle` signature; extend with draft flag.
- `scenes/battle/BattleNetSync.gd` — mirrors the `GameState` from host; may need a `_pvp_draft_seed` field.
- `game_logic/net/BattleNetProtocol.gd` — pure wire helpers; add seed encode/decode if needed.
- `scenes/draft/DraftScene.gd` — full 1-of-3 pick implementation; reuse or fork.
- `autoloads/CardPackRegistry.gd` — `roll_with_pity` logic; may need a new public `generate_sealed_pool(tier: String, count: int, seed: int) -> Array[String]` helper.
- `autoloads/SceneManager.gd` — `enter_pvp_battle` signature; draft duels may route here with `draft=True` flag or a separate `enter_draft_duel` method.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
