# TID-150: Puzzle Shrine Entity + 5 Authored Puzzles

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** TID-149

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-149 builds the puzzle game-logic. This task places puzzle shrines in named maps and authors five concrete puzzles that teach keyword interactions. A shrine is a new world entity — approaching it shows a hint and "Attempt Puzzle"; if the player has already solved it, it glows solved and shows the reward.

## Research Notes

- **PuzzleShrine entity:** New `scenes/world/entities/PuzzleShrine.gd` + `.tscn`. Similar to `StoryScroll.gd` for proximity detection. Export var `puzzle_id: String`. On interact: check `SaveManager.solved_puzzles` — if already solved, show "Solved" dialogue; otherwise launch puzzle via `GameBus.puzzle_requested(puzzle_id)`.
- **Battle scene hook:** `scenes/battle/BattleScene.gd` listens to `puzzle_requested`; loads puzzle via `PuzzleRegistry.get_puzzle(id)` and calls `GameState.load_puzzle(puzzle)`. Must also listen to `GameBus.puzzle_solved` to award `reward_card_id` and return to the world.
- **Visual:** Shrine uses a simple `MeshInstance3D` box or cylinder with a glowing material (emissive colour changes from blue to gold on solve). No new textures required — use `TextureGen` flat colour.
- **5 authored puzzles (PuzzleData .tres):**
  1. `puzzle_surge_lethal` — one Surge minion, one attack needed; teaches Surge keyword.
  2. `puzzle_ward_bypass` — enemy has a Ward minion blocking hero; player has a spell to destroy it first; teaches Ward.
  3. `puzzle_shroud_timing` — player has a Shroud minion; enemy has a board of small minions; player must use Shroud + attack order to win.
  4. `puzzle_two_attack_lethal` — two minions both need to attack face; teaches attack priority.
  5. `puzzle_mana_curve` — player has 3 cards, 5 mana, enemy hero at 5 HP; teaches mana efficiency.
- Each `.tres` needs a `.uid` sidecar (generate with python).
- **Shrine placement:** Place one shrine per named map (madrian, maykalene, farsyth_mansion, blancogov, blancogov_temple) using the `.tres` map format's ENTITY directive.
- `data/puzzles/` — new directory; create 5 `PuzzleData.tres` files.
- `autoloads/PuzzleRegistry.gd` — created in TID-149; this task adds the 5 `.tres` preloads.
- `docs/agent/battle-system.md` — document puzzle shrine interaction flow.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
