# TID-357: Group-aware NPC & story dialogue system

**Goal:** GID-098
**Type:** agent
**Status:** pending
**Depends On:** TID-356

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

When a group plays the story, NPCs that say "you, child" or "brave traveler" should
address the party ("travelers", "you all"). This task builds the **system** to select
group vs solo dialogue and updates the agent-editable dialogue content in the map
`.tres` files; the human-owned story bible (`docs/human/story.md`) is updated
separately in TID-358.

## Research Notes

- **Dialogue source:** NPC dialogue lives in the map data — `npc_data["dialogue"]` and
  `npc_data["after_dialogue"]`, loaded into `TownspersonNPC.init_from_data(data)`
  (`scenes/world/entities/TownspersonNPC.gd`). The map data comes from the `.tres`
  resources in `assets/maps/` (NPC directives). `get_dialogue()` (line ~54) returns
  `_after_dialogue` if `_flag_key` is set, else `npc_data["dialogue"]`.
- **Other dialogue carriers:** `MerchantNPC.gd`, `BountyBoardNPC.gd`, and any
  narration/story overlays. Grep for `"dialogue"` and `Label3D`/dialogue overlays to
  find every place player-facing story text is shown.
- **Design — how to pluralize without forking every line:**
  - *Option A (recommended):* add an optional `dialogue_group` field to NPC data; when
    a co-op session has ≥2 players present, prefer `dialogue_group`, else fall back to
    `dialogue`. Author group variants only for lines that read awkwardly in plural.
  - *Option B:* runtime token substitution (`{you}` → "you all", `{traveler}` →
    "travelers") — lighter authoring but easy to get grammatically wrong.
  - Pick A for control; document the new field in `named-maps-and-dungeons.md`.
- **"Are we a group?" signal:** count connected peers on the same map
  (`NetworkManager.is_active()` + same-map peers from `_remote_player_maps` / roster).
  Single-player and solo-on-a-map both use the singular text.
- **Map `.tres` edits are agent-owned** (`assets/maps/`), so adding `dialogue_group`
  variants for the in-game NPCs is in scope here. The story **bible** text in
  `docs/human/story.md` is human-owned → TID-358 lists the changes for the human.
- Remember `.tres` edits need their `.uid` sidecars untouched/valid; run the headless
  import after editing maps (per CLAUDE.md).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
