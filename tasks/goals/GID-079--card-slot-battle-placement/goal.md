# GID-079: Card Slot Battle Placement

## Objective

Make board slots first-class entities: always visible, centred, explicitly targeted for card placement, and capable of carrying persistent enhancements.

## Context

The current board renders only occupied cards in a plain HBoxContainer — empty slots are invisible and the player has no control over which slot a card lands in. ZoneState already models 5 indexed slots internally, so the data layer just needs a thin extension. Surfacing slot identity in the UI unlocks position-aware mechanics (e.g. "leftmost attacker gets +1 damage", cards that care about neighbours) which the user plans to add as follow-on content.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-291 | Slot-indexed zone data model | agent | done | — |
| TID-292 | Always-visible centred slot UI | agent | done | TID-291 |
| TID-293 | Explicit hand-to-slot placement | agent | done | TID-292 |
| TID-294 | Slot enhancement system | agent | done | TID-291 |

## Acceptance Criteria

- [ ] All 5 board slots are always visible for both players (outlined panels when empty)
- [ ] Slots are centred horizontally in their board area
- [ ] Dragging a card from hand highlights empty slots as drop targets; releasing over a slot plays the card there
- [ ] Tapping a hand card on mobile enters slot-selection mode; tapping an empty slot confirms placement
- [ ] `ZoneState.add_card_at_slot(idx)` and `play_card_at_slot(card, idx)` exist and are used by the UI
- [ ] `ZoneState.slot_enhancements` is serialised/deserialised correctly in `to_dict`/`from_dict`
- [ ] Two new slot-blessing spell cards exist (`bless_slot`, `ward_slot`) and their effects apply on play
- [ ] Enhanced slots display a coloured border; the enhancement is consumed when a minion is placed there
- [ ] BasicAI is unchanged (still picks first empty slot)
