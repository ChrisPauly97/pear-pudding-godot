# TID-403: Maiteln Journey Presence — Companion Avatar on Story Maps and Camps

**Goal:** GID-108
**Type:** agent
**Status:** pending
**Depends On:** TID-402

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The story is a duo road-trip, but Maiteln only exists as a battle companion and one static NPC in madrian. This task gives him a visible travelling presence: an avatar that accompanies the player on story-mode named maps and appears at the wilderness camps, with short ambient lines keyed to the current objective.

## Research Notes

- **Existing Maiteln assets:** autoloads/CompanionRegistry.gd preloads data/companions/maiteln.tres (battle companion, GID-041); madrian has a Maiteln NPC entity with recruitment dialogue (docs/human/story.md "NPC Dialogue by Map").
- **Avatar precedent:** co-op RemotePlayer avatars (scenes/world/, see docs/agent/multiplayer-coop.md) — a Sprite3D-based character that follows position updates. A simpler approach: a follower Node3D that lerps toward a point offset behind the player, clamped to walkable tiles; no pathfinding needed if he teleports to the player when too far (mounts/tap-to-move precedent for movement patterns: docs/agent/tap-to-move.md, docs/agent/rideable-mounts.md).
- **Sprite3D rules:** CLAUDE.md "Sprite3D: Depth Clipping Into Floor" — position.y = pixel_height × pixel_size × 0.5 + margin.
- **When he appears:** story mode only (SceneManager.start_story_mode path), gated on story flags: from `story_intro_complete` (recruited in madrian) until `chapter1_complete`; hidden inside battles. Only on named story maps (madrian after recruitment, maykalene, farsyth_mansion, blancogov, blancogov_temple) and at the TID-402 camp events — not in the sandbox `main` open world except during camp beats (keep scope contained).
- **Ambient lines:** keyed to game_logic/ObjectiveTracker.gd `current_objective(flags)` — one short line per objective state (Scottish-ish register, "wee", per the story bible tone; final line list should come from the approved dialogue in docs/human/story.md where available, generic guidance otherwise). Interaction: tap Maiteln to hear the line (reuse TownspersonNPC interact pattern, scenes/world/entities/TownspersonNPC.gd).
- **Do NOT** call look_at on the isometric camera or break camera follow (CLAUDE.md camera rules).
- Run `godot --headless --editor --quit` after any .gd edit; preload all resources.

- **Co-op (up to 4 players):** this feature must follow the TID-408 design rules (shared-flag arbitration via SessionState, exactly-once beat effects, authority-broadcast narration, single synced Maiteln, no write-through to solo saves). Read TID-408--coop-story-compatibility.md before Plan.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
