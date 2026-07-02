# TID-393: Guildhall Trophies, Garden & Stash Chest

**Goal:** GID-106
**Type:** agent
**Status:** pending
**Depends On:** TID-392

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The guildhall (TID-392) is now a place the party can gather, but it is empty — just a room. This task furnishes it so it visibly reflects the party's shared history and becomes a functional co-op hub, not a blank shell. Three systems are woven in: **trophies** auto-populated from the session's recorded joint boss clears (reusing the GID-046 trophy pedestal pattern), a **shared garden** that grows on session time (reusing the GID-056 growth model), and a **physical stash chest** entity that opens the existing co-op `PartyStashOverlay` (TID-376) on interact. Together they tell a story: "We defeated these bosses together" (trophies), "We've spent N days as a guild" (garden growth), and "We pool our loot here" (stash). The trophies and garden are entirely display/cosmetic (no new game loops), while the stash chest provides a convenient in-world anchor for the party's shared inventory.

## Research Notes

**Trophies — auto-populated from leaderboard history.** The guildhall spawns trophy pedestals like the player home (GID-046 pattern), but instead of reading `SaveManager` fields, it reads session records: for each entry in `SessionState.leaderboards["coop_clears"]` (the joint boss-clear leaderboard populated by TID-391), spawn a trophy pedestal at a designated position showing the boss/floor info. The pedestal display name is the leaderboard entry's metadata (e.g. "Floor 9 Clear — 3 players" or "Ancient Colossus Defeated"). Iterate up to 3 most-recent clears (or all if fewer than 3) with positions (e.g. left/center/right pedestals at (42,50), (50,50), (58,50)). Unlike GID-046 which predetermines trophy predicates, these are **dynamic**: the UI reflects what the party actually achieved. Use the same procedural BoxMesh pedestals (gold color for clarity) and auto-hide a pedestal if no entry exists at that slot.

**Garden — session-scoped, days_elapsed-driven.** Reuse the GID-056 garden plot system but owned by the **session**, not the single-player character. Add `garden_plots: Array[Dictionary]` to `SessionState.guildhall_state` (expand the v7 migration from TID-392). Each plot has `{seed_id, planted_day}` (same shape as SaveManager's `garden_plots`). Three plots spawn at guildhall positions (e.g. (52,54), (55,54), (58,54) — same tile-relative layout as the home for familiarity). `GardenPlot` gains an optional `session_mode: bool` flag; when true, it reads/writes from `SessionStore` (authority-owned) instead of `SaveManager`. On interact, WorldScene shows the same plot panel (plant, growing, harvest) as single-player, but all changes are submitted to the authority via new `NetSync` RPCs: `submit_session_plant(plot_idx, seed_id)` / `submit_session_harvest(plot_idx)` (client → authority). Authority calls `StashTransfer.deposit_seeds(...)` / `withdraw_plants(...)` to move seeds/plants between the acting member's character record and the session stash (decide in Plan: should harvested plants go to the member's `owned_cards` or to the session stash? Guidance: session stash is simpler and thematic — shared garden feeds the shared stash). Authority broadcasts `recv_session_garden_update(plot_states)` so all peers see consistent plots. Garden growth is deterministic from `SessionState.days_elapsed` (authority-owned), so all peers compute identical growth stages locally without needing a per-plot-instance ticker.

**Stash chest entity — interact to open PartyStashOverlay.** A new entity type `entity_type = "stash_chest"` is placed in the guildhall (e.g. tile (50,48)). On interact (key E or tap the on-screen prompt), WorldScene calls `_show_party_stash_overlay()` — the same overlay from TID-376, already fully implemented. The overlay is a convenience: the party stash is already accessible via the always-visible HUD button (TID-376), but having a physical chest in the guild hall reinforces that it is a shared resource. The chest has a `Label3D` label ("Guild Stash" or "Party Treasury") and a subtle idle animation (e.g. slight bob, or a faint glow). No new RPC needed — the chest just routes to the existing overlay.

**Interact prompt — key + tap parity.** All three entity types (trophy pedestals, garden plots, stash chest) follow the existing interact-detection flow: WorldScene's `_check_interactions()` finds the nearest entity within `IsoConst.INTERACT_RANGE`; `_handle_interact()` dispatches by entity type. Pedestals are NPCs (`npc_type = "trophy_pedestal"`, same as GID-046) and show a fixed info dialogue on interact (read-only). Garden plots have their own `_show_garden_plot_panel` branch (existing code, reused here). The stash chest is a new `entity_id = "stash_chest"` branch that calls `_show_party_stash_overlay()`. Mobile users tap an on-screen prompt (existing pattern), desktop users press E (existing pattern). No new keybindings or prompt infrastructure needed.

**Authority-only garden writes.** Plot changes (plant/harvest) are submitted by any peer but executed by the authority. Similar to party bounties (TID-369) and party stash (TID-376), the authority resolves the submitter's token, applies the mutation to the session state, writes via `SessionStore.mark_dirty()`, and broadcasts the updated plot states. A late-joining peer receives the current `guildhall_state.garden_plots` via `_send_character_to_peer` snapshot (same as stash is sent in TID-376). Rejoining members see their guild's garden in its current growth state.

**Leaderboard vs. garden value signal.** The session's pve-leaderboard ("coop_clears") is recorded by TID-391 and feeds trophy populations. The garden is independent — it tracks session time (days elapsed), not wins. Together they show "We've cleared tough encounters (trophies) and we've built this space together (garden visible growth)."

**Project invariants.** All guildhall-interior code guarded by `NetworkManager.is_active()`. New entity interactions follow existing patterns (no new interact dispatch logic). SessionState migration for garden plots (expand TID-392's v7 bump if needed, or call it v8 if TID-392 also adds fields). New GameBus signals for garden events (optional, if re-using existing `GameBus.plant_harvested` from GID-056 causes confusion — decide in Plan). Headless import must pass. No new `.tres` resources (entity data is in-map presets). All interact prompts render viewport-relative and work on touch + keyboard.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
