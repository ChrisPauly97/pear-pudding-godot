# TID-396: Contextual action bar — single slot for proximity-gated actions

**Goal:** GID-107
**Type:** agent
**Status:** done
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

- `ZONE_CONTEXT` (already anchored bottom-center by TID-394) becomes the shared slot.
  Chose the **stacking**, not **shared-button**, approach from the two options in the
  original plan: `_interact_btn` (WorldHUD), `_challenge_btn`/`_ranked_toggle_btn`/
  `_trade_window_mine`/`_spectate_btn` (WorldScene) all register/parent into the same
  `VBoxContainer`. A single swapped-label button was rejected — `_interact_btn`'s
  callback is a fixed `_handle_interact()` dispatch used from many call sites via
  `show_interact_prompt(v, label)`, while Challenge/Trade/Spectate each have their own
  distinct handler and independent show/hide triggers; unifying them into one Button
  would mean rebuilding that whole dispatch surface for no behavioral gain, since
  stacking already makes overlap structurally impossible.
- **Priority order (documented, not merely implicit):** the Android world-interact
  prompt (door/chest/NPC/scroll) always wins the slot over any social action —
  interacting with the world is the more frequent, lower-friction action, and it was
  already effectively "modal" in the old design (WorldScene's own interact-range check
  runs independently of the social-proximity checks, so both could show together
  today, silently colliding). New rule, enforced at the top of
  `_update_challenge_proximity()` and `_update_social_proximity()`: if
  `WorldHUD.is_interact_visible()` is true, hide Challenge/Ranked and Trade/Spectate
  and return before evaluating anything else. Desktop's interact prompt is a
  screen-centered `Label` (`WorldScene.tscn`'s `InteractPrompt`, anchored at 0.5/0.5 —
  not viewport-relative like everything else, pre-existing, out of scope), so it
  never physically contends with the bottom-center contextual bar and is intentionally
  excluded from `is_interact_visible()`.
- Challenge/Ranked and Trade/Spectate can still coexist with each other (that was
  already possible pre-GID-107 — Challenge and Trade both key off the same nearby-peer
  proximity check) — only cross-contention with Interact is resolved by priority.
  Zone-stacking means even that coexistence can no longer produce a pixel overlap.
- `_update_social_proximity()`/`_update_challenge_proximity()`'s existing range/
  eligibility logic is otherwise untouched — only placement changed.

## Changes Made

- `scenes/world/WorldHUD.gd`: the Android `_interact_btn` now goes through
  `register_action("interact", "USE", ZONE_CONTEXT, ...)` instead of manual
  `Button.new()` + `_hud.add_child()` + hand positioning. Added
  `is_interact_visible() -> bool`.
- `scenes/world/WorldScene.gd`:
  - `_ensure_challenge_button()`: "challenge" registered via `register_action` into
    `WorldHUD.ZONE_CONTEXT`. `_ranked_toggle_btn` built directly (needs `.toggled`,
    not `.pressed`) and parented into the zone via the new `get_zone_container()` API.
  - `_ensure_social_buttons()`: "trade" and "spectate" registered via
    `register_action` into the same zone.
  - `_update_challenge_proximity()` / `_update_social_proximity()`: added the
    interact-wins-the-slot priority check described above.
- No behavior change to *when* any of these five actions becomes available — only
  *where* they render, plus the one new priority rule (Interact > Challenge/Trade/
  Spectate) that resolves a collision the old code left ambiguous.

**Not run:** `godot --headless --editor --quit` — same network-policy block as
TID-394/395. Traced `_interact_btn`, `_challenge_btn`, `_ranked_toggle_btn`,
`_trade_window_mine`, `_spectate_btn` across both files with `grep` and re-read every
edited function in full to confirm no dangling references or signature mismatches
(`register_action`'s required non-optional `callback` param is why `_ranked_toggle_btn`
couldn't go through it — verified before writing that branch). Parenthesis/bracket/
brace balance check against the pre-edit files showed no new imbalance.

## Documentation Updates

For TID-398: contextual bar priority order is **Interact > {Challenge/Ranked, Trade,
Spectate}** (documented above); Interact-vs-social is enforced explicitly, Challenge-
vs-Trade-vs-Spectate can still coexist (unchanged from before, now just non-
overlapping). Desktop's interact prompt is a separate screen-centered Label, not part
of `ZONE_CONTEXT`.
