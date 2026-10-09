# BID-096: Shop town_name uses current_map, which is "main" in stitched towns

**Category:** design-inconsistency
**Discovered During:** GID-180 research

## Description

`SceneManager._on_shop_requested` sets `ShopScene.town_name = current_map`. Since GID-138 the outdoor story towns are stitched into `main`, so outdoor merchants get `"main"` and the town-siege gratitude discount (`town_siege.is_town_discounted(town_name)`) never applies there.

## Evidence

`autoloads/SceneManager.gd` `_on_shop_requested`; `scenes/ui/ShopScene.gd:81`; CLAUDE.md "Use `WorldScene.story_place()` (not `map_name`)".

## Suggested Resolution

Pass the story place (`WorldScene.story_place()` / `realm_regions.current_town`). Fix in GID-180 / TID-746, which needs per-town vendor preferences.
