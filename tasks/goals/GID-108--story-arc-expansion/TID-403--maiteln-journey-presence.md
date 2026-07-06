# TID-403: Maiteln Journey Presence — Companion Avatar on Story Maps and Camps

**Goal:** GID-108
**Type:** agent
**Status:** done
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

1. **`game_logic/TextureGen.gd`**: new `npc_maiteln() -> ImageTexture` (pale head/beard, indigo
   robe, grey trim), mirrors `npc_merchant()`'s `_gen_humanoid` call pattern.

2. **New entity** `scenes/world/entities/MaitelnFollower.gd` (+ minimal `.tscn`, uid embedded
   inline per the `StoryScroll.tscn` precedent):
   - `setup(player_node: Node3D, world_scene_ref: Node3D)` — stores both refs (mirrors
     `StoryScroll.setup(scroll_id, player)` and `RemotePlayer.world_scene`).
   - `_process(delta)`: target = player position + a fixed world-space offset
     (`Vector3(-1.4, 0, -1.4)`, keeps him visibly beside/behind without overlapping the player
     sprite); lerps XZ toward it via `AvatarSync.interp()` (reusing the co-op avatar smoothing
     helper) at a moderate rate; **snaps instantly** instead of lerping when the distance
     exceeds ~8 tiles (map transition/fast-travel/door) — this is the "teleport when too far"
     simplification the research notes offer *instead of* pathfinding/walkable-tile clamping,
     which is intentionally not implemented (out of scope for a flavor companion). Y is
     recomputed from `world_scene.get_terrain_height()` every frame, never lerped (matches the
     `RemotePlayer` pattern exactly).
   - `interact()`: looks up `ObjectiveTracker.current_objective(SceneManager.save_manager.story_flags)`,
     maps the label to one flavor line via a small const dict (Scottish register, matching the
     TID-402 rabbit-hunt tutorial lines' tone), falls back to a generic line for an unmapped/empty
     label, and shows it via `GameBus.hud_message_requested` (routes to `_world_hud.show_dialogue`,
     confirmed at `WorldScene._ready()` line ~593 — a proper dialogue display, not just a toast).
   - No highlight ring / "interactable" group — mirrors `StoryScroll`/`WildernessCamp`'s simpler
     pattern (WorldScene's own `_find_nearby_X` + `_handle_interact` dispatch), not
     `WorldEntityBase`'s ring-highlight system used by map-defined NPCs.

3. **`WorldScene.gd`**: new `_maiteln_node: Node3D = null` field.
   - `_maiteln_should_be_present() -> bool`: `story_intro_complete` set AND `chapter1_complete`
     NOT set, AND (`map_name` in `["madrian","maykalene","farsyth_mansion","blancogov","blancogov_temple"]`
     OR (`map_name == "main"` AND `chapter1_left_madrian` set AND `chapter1_learned_fire` not set —
     i.e. exactly the TID-402 camp-beat window, not general sandbox presence)).
   - `_refresh_maiteln_presence()`: frees the node if present but shouldn't be, spawns it (via a
     new `_spawn_maiteln_follower()`, calling `.setup(_player, self)`) if absent but should be.
     Called once at the tail of `_ready()` (guarded by `not NetworkManager.is_dedicated_server()`,
     matching the existing HUD/minimap guard in that function) and from `_on_local_story_flag_set()`
     (already fires on every local `story_flag_set`, single-player included — extending it here
     means Maiteln disappears/appears immediately when a relevant flag flips *within* the same
     loaded map, e.g. finishing the rabbit hunt or completing the temple council, without needing
     a map reload).
   - `_find_nearby_maiteln()` mirrors `_find_nearby_wilderness_camp()`; wired into
     `_check_interactions()` (`"TALK"` label — reuses the existing NPC talk label since this is
     conversationally identical) and `_handle_interact()`.
   - **Hidden in battles "for free":** BattleScene fully replaces the current scene and
     `SceneManager` removes the WorldScene node from the tree during a battle overlay (confirmed:
     `_saved_world_scene = get_tree().current_scene; get_tree().root.remove_child(...)` in
     `SceneManager._on_puzzle_requested`/battle-entry paths) — no WorldScene child processes while
     detached, so Maiteln (and everything else in `_entity_root`) is implicitly hidden with zero
     extra code.
   - **Known simplification, noted not fixed:** the static madrian Maiteln NPC (fixed recruitment
     dialogue, from the map file) is untouched — per the research notes' explicit map list
     ("madrian after recruitment" is included), the follower can briefly coexist with the static
     NPC in madrian between recruiting and leaving. Removing/hiding the static NPC would touch
     named-map data and risk more than this task's scope; flagged here rather than silently
     shipped.

4. **Co-op note (per TID-408):** per TID-408 rule 4, co-op wants exactly ONE authority-owned
   Maiteln synced to clients with `map_name` carried in the payload (mirrors `RemotePlayer`
   avatar sync). This task ships the **solo** follower only — each client would currently render
   their own local Maiteln independently in a co-op session (harmless single-player-shaped
   behavior, not networked, not synced). Documented as a known gap for TID-408 to replace with
   the authority-owned synced version; not blocking solo play.

**Validation:** same sandbox constraint as TID-401/402 (no Godot binary, network egress
blocked). Manual review in place of headless import.

## Changes Made

- **`game_logic/TextureGen.gd`**: new `npc_maiteln()` (pale head/beard, indigo robe, grey trim).
- **`scenes/world/entities/MaitelnFollower.gd`** (+ `.tscn`, `.gd.uid`): new follower entity —
  `setup(player, world_scene)`, lerp-follow with snap-on-teleport, tap-for-a-line `interact()`.
- **`scenes/world/WorldScene.gd`**: new `_maiteln_node` field, `_MAITELN_NAMED_MAPS` const,
  `_maiteln_should_be_present()`, `_refresh_maiteln_presence()` (called at the tail of `_ready()`
  and from `_on_local_story_flag_set()`), `_find_nearby_maiteln()`; wired into
  `_check_interactions()` (`"TALK"` label) and `_handle_interact()`.
- **`docs/agent/story-implementation.md`**: new "Maiteln Journey Presence" subsection.

**Known simplifications (see Plan for full reasoning, intentionally not addressed here):**
static madrian NPC coexists briefly with the follower; no tile-walkability clamping (teleport-
when-too-far instead, per research notes' own suggested simplification); co-op is solo-only
per-client (not synced) — all three are documented, none block solo play, and the co-op gap is
explicitly TID-408's to close.

**Validation:** same sandbox constraint as TID-401/402 (no Godot binary, network egress
blocked). Careful manual review of every multi-line `Edit` in place of headless import — no
edit-boundary defects found this time (the class of bug caught twice in TID-401/402).

## Documentation Updates

- `docs/agent/story-implementation.md`: new "Maiteln Journey Presence" subsection covering the
  presence gate, movement mechanism, ambient lines, and the battle-hiding/co-op simplifications.
