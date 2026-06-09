# TID-158: Author 5 Puzzles + Place Shrines in Named Maps

**Goal:** GID-040
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
