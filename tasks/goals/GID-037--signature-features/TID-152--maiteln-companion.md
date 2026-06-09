# TID-152: Maiteln as First Companion, Story-Flag Gated

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** TID-151

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Maiteln is the player's wizard mentor in the story (docs/human/story.md). Adding him as the first companion ties the narrative to the battle loop — players who progressed through Chapter 1 get a tangible gameplay reward. This task creates his CompanionData and gates him behind the story flag set when he joins Saimtar's party.

## Research Notes

- **Story flag:** Check `docs/human/story.md` and `autoloads/SaveManager.gd` for the flag name set when Maiteln joins. Likely `maiteln_joined` or similar. Use that flag in `CompanionData.unlock_story_flag`.
- **CompanionData file:** `data/companions/maiteln.tres`. Suggested passive: `passive_type = "draw_card"`, `passive_value = 1` (draw 1 extra card at start of each turn — fits a wizard mentor archetype).
- **Portrait:** Maiteln has no dedicated portrait texture yet. Use `TextureGen` to generate a placeholder 64×64 pixel-art portrait (grey robe, white beard) using the existing flat-colour tile approach, or create a simple `ImageTexture` programmatically. Do not require a new art asset.
- **Unlock dialogue:** When the player equips Maiteln for the first time (from CharacterScene), show a one-line TownspersonNPC-style dialogue popup: "An old wizard joins your deck, whispering arcane secrets."
- **CompanionRegistry:** Add `_C_MAITELN := preload(...)` preload constant following the Android preload rule.
- **CharacterScene integration:** The companion picker (added in TID-151) should show Maiteln greyed out / locked with "Join Maiteln in the story to unlock" text if `maiteln_joined` flag is false.
- `data/companions/maiteln.tres` + `data/companions/maiteln.tres.uid` — create both.
- `docs/agent/story-implementation.md` — document Maiteln companion unlock as a story reward.
- `docs/agent/battle-system.md` — update companion section with Maiteln's passive.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
