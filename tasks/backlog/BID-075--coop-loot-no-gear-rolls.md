# BID-075: Co-op session loot grants gear without a rarity / item-level roll

**Category:** design-inconsistency
**Discovered During:** TID-538

## Description

`CoopActivities._roll_equipment_into_loot_grant` (need/greed chest loot) appends the item id straight into the
winner's session record (`owned_weapons` / `owned_armor`, BID-033) and never rolls a `GearRolls` rarity / item
level. Session records don't carry `gear_rolls` at all, so co-op characters' gear is always common ilvl 1 and a
roll earned solo doesn't show on a session character.

## Suggested Fix

Add `gear_rolls` to the session character record (SessionState character schema + `adopt_session_character` /
`export_session_character`), roll with `GearRolls.roll(tier, level, rng)` on the authority in
`_roll_equipment_into_loot_grant`, and keep the better roll like `SaveGear.grant`.
