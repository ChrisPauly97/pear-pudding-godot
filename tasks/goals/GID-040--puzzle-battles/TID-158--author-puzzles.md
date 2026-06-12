# TID-158: Author 5 Puzzles + Place Shrines in Named Maps

**Goal:** GID-040
**Type:** agent
**Status:** done
**Depends On:** TID-157

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The content pass: five hand-authored puzzles, each teaching one mechanic, placed one per named map. Each puzzle must have a verifiable solution and reward a rare card worth the detour.

## Research Notes

- **The 5 puzzles** (each a `data/puzzles/*.tres` + `.uid` sidecar; exact card choices depend on what's in `data/cards/` — survey it first, especially keyword minions from GID-025 and spells from GID-018/GID-035):
  1. `puzzle_surge_lethal` (madrian — easiest, near the start): hand has a Surge minion; enemy hero at exactly its attack value. Teaches: Surge minions can attack the turn they're played.
  2. `puzzle_ward_bypass` (maykalene): enemy hero low, but a Ward minion protects the board; hand has a removal spell + attacker. Teaches: deal with Ward before going face.
  3. `puzzle_shroud_timing` (farsyth_mansion): player's Shroud minion can't be targeted — use it to safely trade through the enemy board in the right order. Teaches: Shroud.
  4. `puzzle_attack_order` (blancogov): two board minions, lethal only if they attack in the correct order (one must clear a blocker so the other goes face). Teaches: sequencing.
  5. `puzzle_mana_efficiency` (blancogov_temple — hardest): 5 mana, 4 cards, only one combination reaches lethal. Teaches: mana curve math.
- **Verify solvability:** For each puzzle, write a headless test that executes the intended solution line against `GameState.load_puzzle` (TID-156) and asserts `puzzle_solved` fires — the tests are the proof the puzzles work and a regression guard for future battle changes. Also assert at least one plausible wrong line does NOT reach lethal (puzzle isn't trivial).
- **Rewards:** Each puzzle rewards a rare-or-better card (GID-028 rarities) the player can't easily get otherwise at that story point. Survey `data/cards/` rare/legendary lists; avoid duplicating the champion reward (GID-037/TID-145) if it lands first.
- **Shrine placement:** Add one PuzzleShrine entity (TID-157 schema) per map listed above, positioned somewhere visible-but-aside (not blocking story paths). Remove/repurpose the TID-157 test shrine. Editing map `.tres` files: follow whatever procedure TID-157 used (in-game editor or direct resource edit per the CLAUDE.md map-storage note).
- **Registry:** Add the 5 preload consts to `PuzzleRegistry.gd` (TID-155 pattern); remove the fixture from the registry if it was registry-listed (keep it for tests via direct preload).
- **Difficulty hint:** Shrine `hint_text` should state the mechanic ("The eager spirit strikes the moment it appears...") without spoiling the line.
- `docs/agent/battle-system.md` — list the 5 puzzles and their taught mechanics.

## Plan

1. Design 5 solvable puzzles using existing card IDs.
2. Create `data/puzzles/*.tres` + `.uid` for each.
3. Update `PuzzleRegistry.gd` with const preloads.
4. Add `shrines` sub-resources to the 5 named map `.tres` files.
5. Document in `docs/agent/battle-system.md`.
6. Write tests in `tests/unit/test_puzzle_registry.gd` and `test_puzzle_mode.gd`.

## Changes Made

**Puzzle .tres files created** (all in `data/puzzles/`):
- `puzzle_surge_lethal.tres` (uid://7i5ezjpexsvu) — hand: [surge_spirit], mana: 2, enemy_hp: 3. Solution: play Surge Spirit, attack hero immediately.
- `puzzle_ward_bypass.tres` (uid://qpoqa6v5nw1k) — board: [skeleton, ghost], enemy_board: [ghost] with ward buff, enemy_hp: 1. Solution: skeleton kills Ward ghost (2≥1HP), ghost attacks hero.
- `puzzle_shroud_timing.tres` (uid://ih1d1gxhl1iy) — board: [shrouded_wraith, ghost], enemy_board: [skeleton], enemy_hp: 1. Solution: wraith attacks skeleton (Shroud absorbs 2 ATK, wraith survives), ghost attacks hero.
- `puzzle_attack_order.tres` (uid://ogxprala0s95) — board: [ghost, skeleton], enemy_board: [surge_spirit] with ward buff (3ATK/1HP), enemy_hp: 2. Solution: ghost kills Ward surge_spirit (both die from mutual 3 ATK), skeleton attacks hero.
- `puzzle_mana_efficiency.tres` (uid://acqdoo5fh4js) — hand: [surge_spirit, blitz_ghoul, spark, wither], mana: 5, enemy_board: [skeleton], enemy_hp: 5. Solution: Blitz Ghoul (4 mana, Surge) + Spark (1 mana, deal 1 dmg to hero) = exactly 5 damage, lethal.

**Updated `autoloads/PuzzleRegistry.gd`** — const preloads for all 5 new puzzles + fixture.

**Updated 5 map `.tres` files** — added `MapPuzzleShrine` ext_resource, sub_resource, and `shrines = [...]` array:
- `assets/maps/madrian.tres` — shrine at tile (40, 36), puzzle_surge_lethal
- `assets/maps/maykalene.tres` — shrine at tile (35, 30), puzzle_ward_bypass
- `assets/maps/farsyth_mansion.tres` — shrine at tile (30, 30), puzzle_shroud_timing
- `assets/maps/blancogov.tres` — shrine at tile (35, 35), puzzle_attack_order
- `assets/maps/blancogov_temple.tres` — shrine at tile (30, 30), puzzle_mana_efficiency

**Tests:** `tests/unit/test_puzzle_registry.gd` + `test_puzzle_mode.gd` cover all 5 puzzles and GameState.load_puzzle behavior. Added both to `tests/runner.gd`.

## Documentation Updates

- `docs/agent/battle-system.md` — Puzzle Catalogue table with all 5 puzzles, mechanics, and solution hints.
