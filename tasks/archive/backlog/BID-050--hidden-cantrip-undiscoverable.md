# BID-050: Locked cantrips are undiscoverable — hidden button can't teach the mechanic

**Category:** design-gap
**Discovered During:** GID-117 / TID-440

## Description

Cantrip HUD buttons are visibility-gated on availability: `_ghost_btn.visible =
CantripManager.is_available("ghost_phase", deck_ids)` (WorldHUD). When the deck doesn't
qualify (starter deck has only 3 of the 4 required Ghost-family cards), the button does not
render at all — so a player has no way to learn that Ghost Phase exists, or that adding one
more Ghost-family card would unlock a wall-phasing ability. The mechanic designed to make
deck-building affect exploration is invisible precisely to the players who haven't engaged
with it yet. (GID-081 correctly removed the *always-on* buttons; the over-correction is
that "locked" and "nonexistent" now look identical.)

## Evidence

- `scenes/world/WorldHUD.gd:140-141` — visibility bound directly to availability.
- `autoloads/SaveManager.gd:330-336` — starter deck: 3× ghost (Ghost Phase family needs ≥4).
- `game_logic/TutorialRegistry.gd` — no cantrip entry exists.
- Full audit table: `docs/agent/game-appeal.md` §7.

## Suggested Resolution

TID-441's cantrip discovery popup partially mitigates this (it mentions that deck
composition unlocks abilities). A fuller fix would show locked cantrips as a disabled/grey
button with a progress hint (e.g. "Ghost Phase — 3/4 Ghost cards"), following the
viewport-relative sizing and action-registry rules in CLAUDE.md. Decide after TID-441 lands
whether the popup alone is sufficient.

## Resolved (GID-122 / TID-463)

Implemented the suggested resolution, with one adjustment: the button stays **enabled**
rather than `disabled` — a Godot `Button` with `disabled = true` never fires `pressed`, so
a truly disabled button couldn't explain itself to a curious tap. Both cantrip buttons are
now always registered visible (`register_action(..., Callable(), ...)` — no
`visible_when` toggle); `WorldHUD._update_cantrip_button_state()` dims a locked button
(`modulate` alpha 0.5) and appends a live progress count to its label (e.g.
`"[G] Phase (3/4)"`) via the new `CantripManager.count_family()` public wrapper. Tapping a
locked button still routes to the existing `_activate_ghost_phase()` /
`_activate_skeleton_dig()` guard, which already emits a "requires N+ family cards" HUD
message — so the fix needed no new dispatch logic, only a visibility/labeling change.
