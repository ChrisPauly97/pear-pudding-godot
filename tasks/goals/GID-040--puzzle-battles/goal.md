# GID-040: Puzzle Battle Shrines

## Objective

Handcrafted "win this turn" board-state puzzles found at glowing shrines in named maps, teaching keyword interactions and rewarding rare cards.

## Context

The keyword system (Ward, Surge, Shroud from GID-025) and status effects (GID-019) have depth that tutorials explain poorly. Puzzle battles teach by doing: the player is handed a fixed board and must find the lethal line. Solved shrines glow gold and are tracked per save, so each puzzle rewards once.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-155 | PuzzleData resource + PuzzleRegistry autoload | agent | pending | — |
| TID-156 | Puzzle mode in GameState + BattleScene (seeding, win/fail/reset) | agent | pending | TID-155 |
| TID-157 | PuzzleShrine world entity + interaction flow | agent | pending | TID-156 |
| TID-158 | Author 5 puzzles + place shrines in named maps | agent | pending | TID-157 |

## Acceptance Criteria

- [ ] PuzzleData defines hand, boards, mana, hero HPs, reward card, and hint text; PuzzleRegistry preloads all puzzle .tres files
- [ ] `GameState.load_puzzle()` seeds a battle from PuzzleData; killing the enemy hero in one turn emits `puzzle_solved`; ending the turn without lethal resets the board
- [ ] PuzzleShrine entities show hint text on approach, launch the puzzle on interact, and glow gold once solved (tracked in `SaveManager.solved_puzzles`)
- [ ] 5 puzzles exist, each teaching a distinct mechanic (Surge, Ward, Shroud, attack ordering, mana efficiency), placed one per named map
- [ ] Solving a puzzle awards its reward card exactly once
- [ ] All tests pass headless
