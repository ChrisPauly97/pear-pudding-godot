# TID-421: Player-Initiated Ambush Bonus (Sneak Attack)

**Goal:** GID-113
**Type:** agent
**Status:** pending
**Depends On:** TID-420

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Rewards the player for approaching an enemy that hasn't noticed them. This is
the "carrot" half of the ambush system (TID-422 is the "stick" half).

## Research Notes

- "Unaware" definition (using TID-420's `_alert_state` enum):
  - Any wanderer-type enemy (`is_tracking() == false`) is *always* ambushable —
    it never has awareness at all today, so every interact-triggered engage on
    a wanderer currently is, by definition, a sneak-up.
  - A tracking-type enemy is ambushable only while its `_alert_state` is IDLE
    (player hasn't entered the TID-420 awareness radius yet, or has broken
    pursuit per TID-423 and returned to idle).
- Trigger point: both engagement paths funnel through `EnemyNPC.engage()`
  (`scenes/world/entities/EnemyNPC.gd:43-57`) — interact-to-engage
  (`WorldScene._handle_interact()`, line ~4977) and proximity-engage
  (`_on_body_entered`, lines 77-89). Determine the ambush flag inside `engage()`
  itself (it already has full access to `_alive`/`_tracking`/alert state) and
  add it to the `enemy_data` dict passed to `GameBus.enemy_engaged.emit(edata)`
  (line 56) — e.g. `edata["player_ambush"] = true`.
- Battle-start advantage to apply — keep it consistent with how other
  battle-start modifiers already work (Gambits, `docs/agent/battle-system.md`
  "Gambits" section) rather than inventing a new mechanism:
  - Cheapest/most consistent option: enemy hero starts at reduced HP (e.g. -20%
    of max, floor at a sane minimum) — mirrors how `Gambits.gd`'s
    `iron_veil`/`wounded_pride` already apply flat HP/armor deltas in
    `BattleScene._apply_gambit_handicaps()` (see
    `docs/agent/battle-system.md` "Handicap Application" table). Follow that
    exact pattern: apply the ambush modifier in `BattleScene._ready()` right
    alongside (or immediately after) `_apply_gambit_handicaps()`, reading
    `enemy_data.get("player_ambush", false)`.
  - Alternative considered: a free first strike (player deals one instance of
    damage before turn 1 starts) — more thematically "sneak attack" but
    interacts with `HeroState.take_damage`/status effects in a less
    battle-scaffolding way; decide during Plan which is simpler to implement
    safely and pick one (don't do both).
- Needs an on-screen confirmation so the player knows they got the bonus —
  reuse the existing banner pattern: `BattleResultUI.show_boss_banner()` /
  `show_phase2_banner()` (`scenes/battle/BattleResultUI.gd`, per
  `docs/agent/battle-system.md` "BattleResultUI" section) is the established
  "floating label with tween-fade" pattern for one-off battle-start banners —
  add a similar `show_ambush_banner()` for "Ambush!" rather than inventing a new
  UI primitive.
- Must survive mid-battle save/resume the same way gambits do — check whether
  `player_ambush` needs to be threaded through `SaveManager.pending_battle_enemy_data`
  the same way `gambit_id` already is (`docs/agent/battle-system.md` "Handicap
  Application" section: "stored as enemy_data['gambit_id']... passed through
  SaveManager.pending_battle_enemy_data... NOT re-applied on restore, already
  baked into the serialized GameState"). Follow the same rule: the HP delta is
  applied once at fresh-battle time and is already part of the serialized
  `GameState` on resume, so no special resume-path handling should be needed —
  confirm this during Plan rather than assuming.
- Rival encounters (`docs/agent/enemies-and-npcs.md` "Rival defeat
  persistence") and duelists have their own engage paths — confirm ambush
  applies only to regular `EnemyNPC.engage()` engagements, not duel-offer-panel
  wagers (`WorldScene._show_duel_offer_panel`) which are a social/consensual
  fight, not a stealth encounter.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
