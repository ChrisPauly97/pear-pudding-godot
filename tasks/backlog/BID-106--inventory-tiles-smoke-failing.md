# BID-106: inventory_tiles_smoke fails on main

**Category:** test
**Discovered During:** GID-187 / TID-789

## Description

`godot --headless --path . -s tests/inventory_tiles_smoke.gd` exits 1 at `4e75fd6` (main before GID-186) with four
card-management failures: "Best deck did not swap in the stronger skeleton copy", "flag for sale did not stick",
"forge drop did not scrap the card for essence", "Sell basket did not sell the flagged card". Unrelated to gear;
CI's scene-smoke step should be red for it (or the failure is environment-specific — check a clean CI run).

## Suggested Resolution

Run the smoke in a clean checkout + import; bisect the card-tile changes that introduced it.
