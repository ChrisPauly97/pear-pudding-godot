# TID-396: Contextual action bar — single slot for proximity-gated actions

**Goal:** GID-107
**Type:** agent
**Status:** pending
**Depends On:** TID-394

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Unlike the always-on co-op buttons handled in TID-395, several HUD buttons are proximity- or state-gated — shown only when something specific is true nearby (near a player, near an interactable, spectating a duel). Today each computes its own fixed position and two of them directly collide: Challenge-to-Battle (`y=vh*0.80`) overlaps the Android USE/Interact button (`y=vh*0.80`), and the Ranked toggle (`y=vh*0.875`) overlaps the Trade button (`y=vh*0.88`). These need one shared bottom-center slot that shows only the single most relevant action for the player's current context.

## Research Notes

Exact current locations in `scenes/world/WorldScene.gd`:
- `_challenge_btn` / `_ranked_toggle_btn` — `_ensure_challenge_button()` ~1758, text "Challenge to Battle"; ranked toggle sits directly below it. Shown when a nearby co-op player is in challenge range (see `_update_social_proximity()` ~4700+, `_CHALLENGE_RANGE` constant).
- `_trade_window_mine` — `_ensure_social_buttons()` ~4606, text "Trade", `.hide()`d by default, shown by the same proximity system, opens via `_open_trade_offer()`.
- `_spectate_btn` — `_ensure_social_buttons()` ~4611, text "Spectate Duel", `.hide()`d by default, shown to non-participants while a nearby duel is active, calls `_request_spectate()`.
- The USE/Interact button lives in `scenes/world/WorldHUD.gd`, not WorldScene: `_interact_btn` (Android only, `show_interact_prompt(v, label)` ~line 307) is shown within `INTERACT_RANGE` of a door/chest/NPC/scroll, positioned at `vw*0.5 - vh*0.09, vh*0.80` — this is the element the Challenge button visually collides with today.
- `_update_social_proximity()` in WorldScene is the function that currently decides which of Challenge/Trade/Spectate should be visible based on nearby players — it already contains priority logic worth reading carefully before changing anything, to avoid regressing which action wins when multiple conditions are true simultaneously.

## Plan

_Written during Plan phase._ Suggested shape (confirm/adjust during Plan):
- Register one contextual-bar zone via TID-394's registry (bottom-center, above the XP bar).
- Define an explicit priority order for what occupies the single slot when multiple conditions could be true at once (e.g. door/chest/NPC interact takes priority over social proximity actions, since interacting with the world is the more frequent, lower-friction action) — decide and document this order, since today's implicit behavior via separate always-checked buttons doesn't cleanly define one.
- Route `_interact_btn` (WorldHUD) and `_challenge_btn`/`_ranked_toggle_btn`/`_trade_window_mine`/`_spectate_btn` (WorldScene) through the shared zone so they never render simultaneously with an overlapping rect — either by sharing one Button that swaps label/callback, or by stacking them in the zone container so it degrades gracefully if two are somehow both true.
- Preserve `_update_social_proximity()`'s existing range/eligibility logic; only change *placement*, not *when* an action becomes available.

## Changes Made

_Filled after Build phase._

## Documentation Updates

_Leave the full `docs/agent/ui-and-scene-management.md` rewrite to TID-398. Note the chosen priority order for the contextual bar in this section for TID-398's reference.
