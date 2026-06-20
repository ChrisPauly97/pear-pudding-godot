# GID-063: Gambits — Pre-Battle Wagers

## Objective

Before engaging an enemy, the player may optionally accept a gambit (a self-imposed handicap) in exchange for multiplied coin rewards and boosted drop rarity.

## Context

Battles currently start instantly on contact: `EnemyNPC.engage()` (`scenes/world/entities/EnemyNPC.gd`, line 73) emits `GameBus.enemy_engaged`, and `SceneManager._on_enemy_engaged()` (`autoloads/SceneManager.gd`, line 226) immediately detaches the world and instantiates BattleScene — there is no pre-battle confirmation of any kind. There is also no risk/reward lever: every win against a given enemy type pays the same coins (`EnemyRegistry.get_coin_reward`, GID-007) and rolls drop rarity from the same tier table (`CardDropUtil.roll_rarity`, GID-028). Gambits add an opt-in difficulty knob that skilled players can pull for better loot, with zero friction for players who ignore it.

Design:

- **Gambit catalogue** (initial set, data-driven const table in `game_logic/battle/`, e.g. `Gambits.gd`):
  - "Wounded Pride" — start at 25 HP (reward ×1.5)
  - "Slow Start" — skip your first draw (reward ×1.5)
  - "Emboldened Foe" — enemy minions +1 ATK (reward ×2)
  - "Iron Veil" — enemy hero starts with 5 armor (reward ×2)
  - Exact numbers tuned in Plan phase.
- **Pre-battle picker**: when an enemy is engaged, a small overlay offers the gambits (mobile-friendly buttons per CLAUDE.md UI sizing rules — viewport-relative, never fixed pixels); "No Gambit" proceeds normally. Must not slow down players who never use it (one tap to skip, or auto-skip option). The picker is skipped entirely when resuming a saved mid-battle state.
- **In-battle badge**: the active gambit is shown as a badge in BattleScene during the fight.
- **Rewards**: on victory, coin reward and drop-rarity roll are multiplied/boosted per the gambit; on loss, normal loss flow (the handicap was the cost).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-224 | Gambit definitions, pre-battle picker UI, rule application in GameState | agent | done | — |
| TID-225 | Reward multipliers + headless tests | agent | done | TID-224 |

## Acceptance Criteria

- [ ] A gambit catalogue const table exists in `game_logic/battle/` defining at least the 4 initial gambits (id, display name, description, handicap parameters, reward multiplier), referenced via `preload()` (never bare `class_name` per CLAUDE.md)
- [ ] Engaging an enemy shows a pre-battle picker overlay with one button per gambit plus a prominent "No Gambit" option; all controls are sized relative to viewport (`get_viewport().get_visible_rect().size`), never fixed pixels, and are fully usable by touch
- [ ] "No Gambit" (one tap) starts the battle exactly as today; an auto-skip option (persisted via SaveManager settings) bypasses the picker entirely for players who never use gambits
- [ ] The picker does NOT appear when restoring a saved mid-battle state (`SaveManager.pending_battle_state` non-empty / `pending_battle_enemy_data` resume path in `WorldScene.gd` line 238–239)
- [ ] Each gambit's handicap is correctly applied at battle start: Wounded Pride sets player hero HP to 25; Slow Start skips the player's turn-1 draw; Emboldened Foe gives every enemy minion +1 ATK (including boss phase-2 deck); Iron Veil gives the enemy hero 5 armor via the existing `armor` status
- [ ] The active gambit is stored in the battle's `enemy_data` / pending-battle dictionaries so it survives mid-battle save/resume, and the handicap is not re-applied on restore
- [ ] BattleScene shows a visible badge naming the active gambit for the whole fight; no badge when no gambit is active
- [ ] On victory with a gambit, the coin reward in `SceneManager._on_battle_won()` is multiplied by the gambit's multiplier, and the drop-rarity roll is boosted (e.g. drop tier bump into `CardDropUtil.roll_rarity`); the gambit id is read before `clear_pending_battle()` is called
- [ ] On loss, the normal loss flow runs unchanged — no penalty beyond the handicap itself
- [ ] Headless tests cover: gambit table integrity, each handicap's effect on `GameState`/`PlayerState`/`HeroState`, reward multiplier math, and no-gambit defaults; new suite registered in `tests/runner.gd` and `godot --headless --path . -s tests/runner.gd` exits 0
- [ ] `docs/agent/battle-system.md` (and `ui-and-scene-management.md` for the picker/scene-flow change) updated
