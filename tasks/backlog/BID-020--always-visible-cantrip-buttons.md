# BID-020: Cantrip HUD buttons are always built regardless of unlock state

**Category:** code-smell
**Discovered During:** GID-081 / TID-298 research

## Description

The overworld HUD always constructs the `[G] Phase` and `[D] Dig` cantrip buttons, even for players who have not unlocked those cantrips. Unlike the `Mount` button (which is hidden until the mount is owned, via `_on_mount_state_changed`), the cantrip buttons have no visibility gating tied to whether the player can actually use them. This clutters the HUD with non-functional controls and is part of the broader "overloaded HUD" complaint that motivated GID-081.

## Evidence

- `scenes/world/WorldScene.gd:411–425` — `ghost_btn` and `dig_btn` are added unconditionally in HUD construction.
- Contrast `scenes/world/WorldScene.gd:394–403` — `_mount_btn` starts hidden and is shown only on `GameBus.mount_state_changed`.
- Cantrip availability/unlock state lives in `CantripManager` (see `docs/agent/card-cantrips.md`).

## Suggested Resolution

Gate cantrip button visibility on whether the player has the corresponding cantrip available (mirror the Mount button pattern: hide by default, show via a CantripManager/GameBus signal or a state check on HUD build and on unlock). Fix opportunistically during TID-298 (HUD declutter), where the cantrip buttons are being regrouped anyway.
