# BID-008: CardData.to_template_dict() omits is_unique, breaking the sell/scrap guard

**Category:** code-smell
**Discovered During:** GID-061 research

## Description

`InventoryScene` (line ~394) guards selling/scrapping unique cards by checking an
`is_unique` flag on the card template dict — but `CardData.to_template_dict()` never
copies `is_unique` into the dict, so the guard always sees `false`. Unique cards are
currently sellable/scrappable despite the guard existing.

## Evidence

- `data/CardData.gd` — `to_template_dict()` field list omits `is_unique`
- `scenes/ui/InventoryScene.gd:394` — guard reads the missing key (defaults false)

## Suggested Resolution

Add `is_unique` to `to_template_dict()`. GID-061 / TID-219 plans to fix this as part of
making Soulbind signature cards unsellable; fix standalone if that goal is deprioritized.
