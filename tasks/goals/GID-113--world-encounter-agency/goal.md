# GID-113: World Encounter Agency — Ambush, Evasion & Enemy Pursuit

## Objective

Give the player positional agency over overworld enemy encounters — sneak up
on an enemy for a battle-start advantage, get caught off guard by a hunting
enemy, or outrun a chaser before it catches you — instead of today's flat
walk-into-a-trigger-and-fight-no-matter-what.

## Context

`scenes/world/entities/EnemyNPC.gd` is entirely static. "Tracking" enemy types
(`EnemyRegistry.is_tracking()`: `undead_elite`, `ghoul_pack`, `roaming_terror`,
plus all dungeon/spire/named-map-depth enemies) get an `Area3D` sphere of
radius `IsoConst.AUTO_BATTLE_RANGE` (1.5 units) that force-triggers a battle the
instant the player's body enters it — the enemy itself never moves.
"Wanderer" types (`undead_basic`, `undead_horde`, duelists) only engage via the
interact button, with zero awareness of the player at all. Notably,
`IsoConst.TRACKING_SPEED` (2.5 world units/sec) is already declared with the
comment "reserved for future movement AI" but has never been consumed anywhere
in the codebase — this goal is exactly that reservation coming due.

There is no risk/reward for how the player approaches an encounter: sneaking up
on a wanderer from behind gives no advantage, and a tracking enemy gives no
warning before it "catches" you (it doesn't even move — it's just a trap tile).
This goal adds a lightweight detection/awareness state to tracking enemies
(using the existing `Pathfinder` from the tap-to-move feature for movement) and
ambush bonuses/penalties keyed off of it, plus a way to break pursuit.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-420 | Real pursuit movement for tracking enemies | agent | pending | — |
| TID-421 | Player-initiated ambush bonus (sneak attack) | agent | pending | TID-420 |
| TID-422 | Enemy-initiated ambush penalty + fair-warning indicator | agent | pending | TID-420 |
| TID-423 | Evasion: break pursuit / outrun a chasing enemy | agent | pending | TID-420 |
| TID-424 | Detection/ambush state machine tests + doc update | agent | pending | TID-421, TID-422, TID-423 |

## Acceptance Criteria

- [ ] Tracking-type enemies (`is_tracking() == true`) actively move toward the player using `IsoConst.TRACKING_SPEED` once the player enters a new "awareness" radius (larger than `AUTO_BATTLE_RANGE`), instead of sitting still behind a static proximity trigger.
- [ ] A player who reaches interact/collision range on an enemy that has not yet noticed them (a wanderer, or a tracking enemy still outside its awareness radius / not yet alerted) gets a battle-start advantage ("Ambush!").
- [ ] A player caught by a tracking enemy's pursuit without reacting in time gets a battle-start penalty ("Ambushed!"), with a clear, fair on-screen/audio warning before it happens (not a surprise the player had no way to see coming).
- [ ] The player can break an active pursuit by putting enough distance/time between themselves and the chasing enemy; the enemy visibly gives up and returns to idle instead of an inevitable forced engage.
- [ ] Mobile/desktop parity is preserved for any new indicator (per CLAUDE.md's Mobile/Desktop Feature Parity rule) — no keyboard-only or touch-only signal.
- [ ] Co-op (`NetworkManager.is_active()`) behavior is either extended consistently or explicitly scoped out with a documented reason — confirm during Plan which named maps / world contexts this applies to (infinite world only, named maps only, or both) since co-op is currently pinned to a single shared named map (madrian).
- [ ] `docs/agent/enemies-and-npcs.md` "Mixed engagement" section is rewritten to describe the new detection/pursuit/ambush system in place of the current binary tracking/wanderer split.
