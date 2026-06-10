# BID-007: test_card_registry asserts 40 cards but registry preloads 46

**Category:** code-smell
**Discovered During:** GID-062 research

## Description

`tests/unit/test_card_registry.gd` asserts an exact card count of 40, but
`CardRegistry.gd` currently preloads 46 cards. Either the test is failing today or the
assertion is written in a way that doesn't actually run/compare what it claims. Exact-count
assertions go stale every time a content goal adds cards (GID-018, GID-025, GID-035 all did).

## Evidence

- `tests/unit/test_card_registry.gd:26` — asserts 40
- `autoloads/CardRegistry.gd` — 46 preload constants

## Suggested Resolution

Run the headless suite to confirm current status, then change the assertion to a
minimum-count check (`>= N`) or derive the expected count from the registry's preload
list. Any card-content task (e.g. GID-062 / TID-223) must reconcile this before adding
more cards.
