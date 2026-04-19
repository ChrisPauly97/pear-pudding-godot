# TID-064: Implement FLAG Map Entity Syntax in Parser

**Goal:** GID-020
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The named-map parser currently supports a simple `NPC x z dialogue text` directive with a single static string. To support flag-gated dialogue, the MapNpc resource needs to store a flag_key and alternate dialogue texts, and the parser needs to extract them from the map directive.

## Research Notes

- Named maps are now stored as `.tres` `MapData` resources (GID-017); the text format `.txt` still works via shim
- `game_logic/battle/resources/MapNpc.gd` is the resource class for NPC entities — add fields: `flag_key: String`, `dialogue_before: String`, `dialogue_after: String` (dialogue_after holds alternate post-flag text; keep existing `dialogue` as the default/before-flag line)
- The `.tres` map editor (`scenes/ui/MapEditorScene.gd`) and the legacy `.txt` parser both need to support the new fields
- Proposed directive syntax for `.txt` format: `NPC x z FLAG:flag_key text_before || text_after`
  - `FLAG:flag_key` is optional; if absent, behavior is unchanged
  - `||` is the separator between before and after text
  - Example: `NPC 49 9 FLAG:chapter1_received_letter Halt! State your business. || Welcome back, traveller.`
- For `.tres` maps: the MapEditorScene should expose flag_key, dialogue_before, dialogue_after fields in the NPC placement panel
- Parse defensively: if `||` is absent after a FLAG: directive, treat the whole text as dialogue_before and leave dialogue_after empty (NPC goes silent after flag — acceptable fallback)

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
