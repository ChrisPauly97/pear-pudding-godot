# BID-085: Level-1 hero nearly dies after one fight and can't heal

**Category:** design-gap
**Discovered During:** playtest feedback (mobile, fresh character), follow-up to BID-084

## Description

A level-1 hero (Strike only, no hand) came out of a starter fight near death. HP carries between fights
(TID-543), out-of-combat regen took 240 s to refill, a new character had no food, and the town full-heal only fires
on *entering* a town. BID-084 had removed enemy summons entirely, but the player wants to see enemies summon — and
their own (locked) slots — so the hand reads as something to look forward to.

## Resolution

- `HeroVitality.regen_seconds(level)`: 45 s empty→full at level 1, linear to 240 s at level 10; `HeroHealth` uses it.
- `new_game` grants `HeroVitality.STARTER_FOODS` (3 Travel Bread), usable via Q / the HUD Eat button.
- `CombatOnboarding.enemy_minion_cap()`: enemies field 1 minion before `feat_minions` (was 0 in BID-084), 2 after.
- `AllySlotLocks.gd`: your empty Ally slots stay on the board under "Locked · Allies at Lv 4" plates until
  `feat_minions` is learned (previously the whole player board was hidden).

Tests: `test_hero_vitality`, `test_combat_onboarding`, `test_realtime_adds`.
