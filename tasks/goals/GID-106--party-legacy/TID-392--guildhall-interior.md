# TID-392: Party Guildhall Interior & Entry

**Goal:** GID-106
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The co-op session today is a shared world to explore together, but it has no **permanent gathering place** — the party has no "home." The single-player Player Home (GID-046) shows that an interior map can display personal history (trophy pedestals). This task extends that pattern to co-op: a **session-owned guildhall interior map** that all party members can enter together. The guildhall is a separate map from the single-player home — it reflects the party's collective identity, not any one player's house. Entry is via a HUD button (host-only, same pattern as co-op Spire TID-390) that broadcasts a map transition so the whole party enters together (reusing `NetSync.recv_map_transition`, TID-355). The guildhall is stored in the session state, so it persists across reconnects: a rejoining member lands back in the guild hall they last entered. All peers render each other inside via the existing map-scoped avatar sync (TID-352), making the space feel shared and inhabited. Single-player never sees the guildhall — it is gated entirely by `NetworkManager.is_active()`.

## Research Notes

**Map creation — reuse Player Home pattern (GID-046, CLAUDE.md map-storage rules).** The guildhall is a new `.tres` resource in `assets/maps/guildhall.tres` (or `guildhall_interior.tres`). It follows the same interior structure as `player_home.tres`: a 100×100 tile grid, WALL=1 boundary, GRASS=0 interior floor (e.g. tiles x:40–60, z:45–60 for a larger gathering space than the home), `spawn_x`/`spawn_z` at center. Add an **exit door entity** with `entity_id = "guildhall_exit"`, positioned at the entry edge, `target_map = ""` to pop back to madrian. Do **not** add an NPC bed or `npc_type = "bed"` — guildhall is a meeting space, not a rest location. Per CLAUDE.md, add a `const _GUILDHALL := preload("res://assets/maps/guildhall.tres")` line to `MapRegistry.gd` and add `"guildhall"` to the `_BUNDLED` dictionary. Generate a 12-character `.uid` sidecar file immediately (format: `uid://a1b2c3d4e5f6`), both to keep Godot's editor scanner happy and to ensure Android exports include the `.tres`.

**Session state tracking — new SessionState field with version bump.** Add `guildhall_state: Dictionary` to `SessionState` (v6→v7 migration, `_migrate_v6_to_v7`). Shape: `{purchased: bool, members_inside: Array[String]}` where `members_inside` tracks member tokens currently in the guildhall (for display/cosmetics, populated by avatar sync). `SessionState.has_guildhall() -> bool` returns `purchased`. A dedicated `_ensure_guildhall(token, name)` method on SessionState initializes the guildhall on first session load (auto-purchased, no coin cost — it is a feature unlock, not a purchasable good like the home). The migration backfills `guildhall_state = {purchased: true, members_inside: []}` for all sessions, so all co-op parties have access immediately without per-session purchasing.

**Entry point — host-only "Enter Guildhall" HUD button.** WorldScene gains a button (viewport-relative, sized per CLAUDE.md) visible only when `NetworkManager.is_active()` and `NetworkManager.is_host()`. On press, check `SessionStore.get_state().has_guildhall()` (always true post-migration, but guard for safety) and call `SceneManager.enter_map_coop("guildhall")` (reusing the existing coop entry point, or a new `enter_guildhall_coop()` variant). The call broadcasts `NetSync.recv_map_transition("guildhall", "spawn")` (TID-355 pattern) so the whole party enters together. Non-hosts cannot initiate entry (prevent confusion/desync), but follow the broadcast and land in the guildhall on the same step.

**Avatar sync — map-scoped (TID-352 pattern).** Avatars inside the guildhall sync normally via the existing `NetSync.recv_avatar()` flow. `AvatarSync.encode` carries `map_name` (the 5th element added in TID-352), and `_on_avatar_received` filters: only show an avatar when its map equals the local `map_name`. So if a member walks out of the guildhall to madrian via the exit door, their avatar disappears from the guildhall peers' view (hidden, not freed, for instant re-convergence if they re-enter).

**Single-player unchanged.** The guildhall button is never shown to single-player (guarded by `NetworkManager.is_active()`). The guildhall map file is a co-op-only asset — single-player code paths never reference it, so single-player exports are unchanged (though the map file is still bundled via MapRegistry, which is autoload-scanned on every export).

**Project invariants.** All guildhall entry/state code guarded by `NetworkManager.is_active()`. New `.tres` resource has `.uid` sidecar. SessionState version bump + migration. New avatar/exit-door entity types (same as existing templates, no new entity code needed). Headless import must pass.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
