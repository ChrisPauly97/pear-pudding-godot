# BID-084: Level-1 hero faces summoning enemies

**Category:** design-gap
**Discovered During:** playtest feedback (mobile, fresh character)

## Description

Before `feat_minions` a real-time fight hides the hand and the player's unit slots (CombatOnboarding), so a
level-1 hero has only Strike + auto-attack. Enemies still summoned up to `MAX_ENEMY_MINIONS` (2) minions, which the
player had no board to answer — "just Strike against an enemy that can summon is rough".

## Evidence

`RealtimeCombat._init_side` gave every enemy side `max_units = MAX_ENEMY_MINIONS` regardless of what the player
had learned; `CombatOnboarding` gated only the player's side.

## Resolution

Same pattern as heavy blows (gated on Kick): `CombatOnboarding.enemy_summons(learned)` (true once `feat_minions` is
learned). Otherwise `BattleRealtime` calls `RealtimeCombat.set_enemy_minion_cap(0)`, which sets `max_units = 0` on
every enemy side and on adds that join later (`enemy_minion_cap`), so enemy `can_play` rejects minion cards. Tests:
`test_combat_onboarding`, `test_realtime_adds`.

**Superseded by BID-085:** playtest wanted enemies to summon early (so the player sees what's coming), so the
pre-`feat_minions` cap is 1, not 0 (`CombatOnboarding.enemy_minion_cap`).
