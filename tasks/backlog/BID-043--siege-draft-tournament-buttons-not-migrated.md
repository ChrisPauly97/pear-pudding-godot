# BID-043: Siege / Draft Duel / Tournament buttons not migrated to the HUD registry — and Siege collides with Tournament

**Category:** code-smell / design-gap
**Discovered during:** GID-107 / TID-398

## Summary

GID-107's goal.md enumerated always-on/proximity-gated HUD buttons as of the goal's
authoring, but three buttons shipped after that list was written (or were otherwise
missed) and TID-395/396/397 deliberately stuck to the goal's explicit scope rather
than silently expanding it:

- `_siege_btn` (GID-103, `_ensure_siege_button()`, `scenes/world/WorldScene.gd`) —
  host-only, shown on siege-supported maps when no siege is active.
- `_draft_duel_btn` (GID-104, `_ensure_draft_duel_button()`) — proximity-gated.
- `_tournament_btn` (GID-104, `_ensure_tournament_button()`) — host-only.

**Concrete bug found while writing the TID-398 regression test:** Siege
(`(vp.x - vp.y*0.22)*0.5, vp.y*0.63`) and Tournament
(`(vp.x - vp.y*0.28)*0.5, vp.y*0.63`) are both centered horizontally at the same
**y = vp.y*0.63**, with Tournament's wider box (`0.28` vs `0.22`) extending past
Siege's edges — they visually overlap in the (host, siege-supported map, no active
siege, no active tournament) state, which is reachable.

## Suggested fix

Fold all three into the GID-107 registry: Siege and Tournament (host-only) are
natural fits for the Party panel or a new host-controls section; Draft Duel
(proximity-gated) belongs in `WorldHUD.ZONE_CONTEXT` alongside Challenge/Trade/
Spectate/Interact (see `docs/agent/ui-and-scene-management.md` "HUD Action Registry
& Party Panel"). `tests/unit/test_hud_registry_guardrail.gd`'s
`_ALLOWED_DIRECT_HUD_CHILDREN` allow-list documents these three as known,
reviewed exceptions — remove them from that list as each is migrated.
