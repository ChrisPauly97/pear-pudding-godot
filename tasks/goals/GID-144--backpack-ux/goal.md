# GID-144: Backpack / Inventory UX

## Objective

User request (2026-09-28): make the backpack / inventory look nicer, make it
clear what each item in the bag is, and improve the ergonomics of managing the
inventory, crafting and turning cards into essence.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-597 | Card-face bag tiles, search/sort, bulk sell/scrap, Craft + Items panels | agent | done | — |

## Changes Made

- `scenes/ui/inventory/CardTile.gd`: bag tiles are mini cards (cost gem,
  rarity frame, art or monogram, name, ⚔/♥ or "Spell", veterancy chevrons,
  "In <deck>" tag, select check).
- `game_logic/inventory/BagOps.gd`: pure sort (name/rarity/cost/power/newest),
  search (name, rules text, keywords), deck membership, "Extras" pick (keeps
  the best copy per card; never deck, unique, renamed or veteran copies), bulk
  value.
- `InventoryScene`: Cards / Craft / Items tab row with a shared wallet line
  (bag, gold, essence); toolbar with search, sort cycle and Select mode; bulk
  bar (Extras, None, Sell +Xg, Scrap +Ye) behind a confirm; a gesture hint
  line; HFlow grid that fits the panel width; detail popup shows mana/class,
  rules text, veterancy, which deck the card is in, Add to Deck and Inspect,
  and Combine for any tier below legendary with an n/3 count.
- `scenes/ui/inventory/CraftPanel.gd` (extracted): recipe rows show cost gem,
  stats, rules text and "Owned ×N"; price on the button; search; status line.
  Fixes essence being spent when the bag was full.
- `scenes/ui/inventory/ItemsPanel.gd`: potions and herbs with counts, effects
  and where they're used. `GardenDefs` POTIONS/PLANTS gain `description`.
- Tests: `test_bag_ops`; `menu_hub_smoke` drives sort, search, the Craft and
  Items tabs and an Extras → bulk scrap.
