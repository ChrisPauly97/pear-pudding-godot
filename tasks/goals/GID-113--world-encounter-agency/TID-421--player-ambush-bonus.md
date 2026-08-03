# TID-421: Player-Initiated Ambush Bonus (Sneak Attack)

**Goal:** GID-113
**Type:** agent
**Status:** done
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

**Ambush classification (shared with TID-422):** in `EnemyNPC.engage()`, capture
`_alert_state` before anything else runs. `player_ambush = (_alert_state ==
AlertState.IDLE)`. This correctly covers wanderers for free — a `_tracking ==
false` enemy never gets an awareness `Area3D` wired (TID-420), so its
`_alert_state` never leaves the default `IDLE`, meaning "is this enemy
IDLE?" already equals "did the player sneak up?" for both wanderers and
not-yet-alerted tracking enemies, with no extra `_tracking` branch needed.
`ALERTED` (mid-reaction, not yet chasing) counts as neither bonus nor
penalty — a neutral fight; only `IDLE` grants `player_ambush` and (TID-422)
only `CHASING` grants `enemy_ambush`. This makes the two flags mutually
exclusive by construction (different enum values), satisfying TID-422's
requirement with no extra guard.

**Mechanism (decided over the two options in Research Notes):** reduced enemy
hero HP, mirroring `Gambits.gd`'s `wounded_pride` shape exactly — set *both*
`health` and `max_health` to `round(max_health * 0.8)` (floored at 10), not
just current `health`, so the handicap survives the whole match instead of
being healed away by the first enemy heal card. Rejected the "free first
strike" alternative — it would need new `HeroState.take_damage` plumbing
before turn 1 even starts, more surface area than a one-line HP set that
already has two precedents in this exact codebase.

**TID-422 will mirror this by reducing the *player's* hero HP by the same
20%/floor-10 shape** (not a different mechanic like hand-size) — this is the
"read from the same code shape" resolution: both ambush outcomes are HP
deltas applied to the loser of the encounter, just aimed at different
targets (enemy for the player's bonus, player for the enemy's penalty),
which already reads as "real opposites" from the player's perspective
without inventing a second mechanism.

**Integration point:** new `BattleScene._apply_ambush_modifiers(enemy_data)`,
called immediately after `_apply_gambit_handicaps(_gambit_id)` in
`_setup_solo_battle()` (line ~461) — confirmed that call site only runs on
the fresh-battle branch of `_ready()` (the `else: _setup_solo_battle()` arm,
never the `pending_battle_state`/resume branch), so no resume-path handling
is needed: the HP delta is baked into `GameState` the moment it's set and
`from_dict()` restores it as ordinary hero HP on resume, exactly like
`wounded_pride` already does.

**Banner:** new `BattleResultUI.show_ambush_banner(is_bonus: bool)` —
"Ambush!" (green) / "Ambushed!" (red, TID-422), own `_ambush_banner` field so
it never fights `_boss_banner`'s fade/replace bookkeeping, positioned at
`_vh * 0.16` (below the boss banner's `0.08` so both can show at once for a
boss ambush without overlapping).

**Scope check:** confirmed rivals (`enemy_type` starting `rival_`) are
regular `EnemyNPC` instances that call the same `engage()`, so ambush applies
to them too (desired — no exclusion needed). Duel-offer-panel wagers never
call `EnemyNPC.engage()` at all (separate `duel_requested` signal path via
`TownspersonNPC`/`MapNpc`), so they're excluded automatically with no guard
needed.

## Changes Made

- `scenes/world/entities/EnemyNPC.gd`: `engage()` now captures `player_ambush
  = (_alert_state == AlertState.IDLE)` and `enemy_ambush = (_alert_state ==
  AlertState.CHASING)` before flipping `_alive`, and adds both to `edata`
  passed via `GameBus.enemy_engaged`.
- `scenes/battle/BattleScene.gd`: new `_apply_ambush_modifiers(enemy_data)`,
  called right after `_apply_gambit_handicaps(_gambit_id)` in
  `_setup_solo_battle()`. On `player_ambush`, sets enemy hero `health` and
  `max_health` to `round(max_health * 0.8)` (floor 10) and shows the ambush
  banner. `enemy_ambush` branch (mirror, player hero) implemented in the same
  pass since it shares this integration point — see TID-422 for its half.
- `scenes/battle/BattleResultUI.gd`: new `show_ambush_banner(is_bonus: bool)`
  ("Ambush!" green / "Ambushed!" red), own `_ambush_banner` field.
- Verified: headless editor import clean.

## Documentation Updates

- Deferred to TID-424 (goal's dedicated docs task), which covers the full
  `enemies-and-npcs.md` rewrite once TID-421/422/423 are all in — noted here
  so the "Integrations" table's `player_ambush`/`enemy_ambush` row lands in
  one pass instead of three partial edits. `docs/agent/battle-system.md`
  Gambits section cross-reference is TID-424's job per its own task notes.
