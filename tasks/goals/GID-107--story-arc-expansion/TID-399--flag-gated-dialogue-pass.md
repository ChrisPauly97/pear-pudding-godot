# TID-399: Flag-Gated Dialogue Content Pass Across All Named Maps

**Goal:** GID-107
**Type:** agent
**Status:** pending
**Depends On:** TID-395

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The FLAG map-entity syntax and TownspersonNPC flag routing were built in GID-020 (TID-064/TID-065) but content was never authored (backlog BID-016). The approved dialogue table now exists in docs/human/story.md ("Flag-Gated Dialogue States"). This task applies it to every NPC across the 5 named maps.

## Research Notes

- **Source of truth:** docs/human/story.md — "Flag-Gated Dialogue States" table: 11 NPCs across madrian (Master, Maiteln), maykalene (Townsperson, Innkeeper, Mansion guard), farsyth_mansion (Lord Farsyth), blancogov (Gate guard — already wired, City dweller), blancogov_temple (King Eldar, Queen, Scargroth). Flag keys used: story_intro_complete, chapter1_warned_farsyth, chapter1_received_letter, chapter1_temple_council, chapter1_complete.
- **FLAG syntax:** `NPC x z FLAG:flag_key before_text || after_text` (implemented by TID-064 in the WorldMap parser; TID-065 wired TownspersonNPC.get_dialogue() routing). Verify exact syntax in the parser (game_logic/world/ WorldMap parsing code) before editing maps.
- **Maps are .tres now** (GID-017): assets/maps/*.tres preloaded by autoloads/MapRegistry.gd. NPC dialogue lives in the map resource entity data — edit the .tres files (text format) for madrian, maykalene, farsyth_mansion, blancogov, blancogov_temple. The gate guard's chapter1_received_letter gating may already exist (WorldScene.gd ~line 2901 references it) — check for double-wiring.
- **Scargroth's chapter1_complete after-line** is the parents-mystery hook ("…there is a name from Larik you should see") — must match story.md exactly.
- Existing test precedent: tests/ has NPC/parser tests; add or extend a test asserting flag routing returns the correct line for at least one before/after pair per map.
- Resolves backlog item BID-016 (already marked resolved in tasks/index.md when this goal was created — confirm and archive the BID file if not done).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
