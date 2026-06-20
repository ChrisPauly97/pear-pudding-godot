# GID-062: Dual-Faced Corruption Cards

## Objective

Dual-faced cards resolve as their Light or Dark face depending on the player's current corruption/redemption alignment, chosen at battle start with a flip visual — the moral path literally changes what your cards do.

## Context

The skill system (GID-032) introduced two moral currencies tracked on `SaveManager`: `corruption_points` (earned via dark dialogue choices) and `redemption_points` (earned via light dialogue choices). Today they only gate cross-magic skill purchases. This goal makes them matter in every battle: dual-faced cards read the player's alignment and resolve as a Light or Dark face.

Design:

- A dual-faced card references two face definitions. Two candidate models: (a) two `CardData` resources linked by `dark_face_id` / `light_face_id` fields, reusing all existing template/registry/rendering machinery; or (b) face fields embedded in a single `CardData` (a `dark_*` mirror of every gameplay field). The choice is made in the TID-221 Plan phase; trade-offs are captured in its Research Notes.
- Alignment resolution: compare `SaveManager.corruption_points` vs `redemption_points` at battle start. Corruption > redemption → Dark face; redemption > corruption → Light face. Ties default to Light (or last-chosen — Plan decision in TID-221). The face is fixed for the whole battle, including mid-battle save/resume.
- UI: a flip animation plays when the hand is dealt / a dual-faced card is first shown; `CardInspectOverlay` shows BOTH faces so players can plan ahead; the collection/inventory shows the face matching the player's current alignment with an indicator that the card is dual-faced.
- Content: 6 dual-faced cards spanning the four magic branches (ember / dawn / dusk / ash), each with meaningfully different Light/Dark behaviour (not just stat swaps — e.g. `heal_all` vs `deal_damage_all`).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-221 | Alignment resolution + dual-face CardData model, face chosen at battle start | agent | done | — |
| TID-222 | UI: face-flip visual, inspect overlay shows both faces | agent | done | TID-221 |
| TID-223 | Content: 6 dual-faced cards spanning the four branches | agent | done | TID-221 |

## Acceptance Criteria

- [ ] `CardData` supports dual faces (linked face IDs or embedded face fields, per Plan decision) with backward-compatible defaults so all existing `.tres` cards are untouched
- [ ] At battle start, each dual-faced card in the player's deck resolves to its Light face when `redemption_points >= corruption_points` (tie rule per Plan decision) and its Dark face when `corruption_points > redemption_points`
- [ ] The resolved face is fixed for the entire battle and survives mid-battle save/resume (`GameState.to_dict()` / `from_dict()` round-trip)
- [ ] A flip animation plays the first time a dual-faced card is shown in the hand during a battle
- [ ] `CardInspectOverlay` shows both the Light and Dark face for a dual-faced card, with the active face clearly marked
- [ ] InventoryScene (collection/deck builder) shows the face matching current alignment plus a visible dual-faced indicator
- [ ] 6 dual-faced cards exist in `data/cards/` covering ember, dawn, dusk, and ash, each with meaningfully different Light/Dark behaviour (different effects, not just stat swaps)
- [ ] All new `.tres` files have `.uid` sidecars and are preloaded as `const` entries in `autoloads/CardRegistry.gd` (Android packaging rule)
- [ ] Hidden Dark/Light face resources do not appear as standalone cards in ShopScene, crafting, or drop pools
- [ ] `docs/agent/battle-system.md` (and `inventory-and-deck.md` if collection UI changed) updated; tests pass via `godot --headless --path . -s tests/runner.gd`
