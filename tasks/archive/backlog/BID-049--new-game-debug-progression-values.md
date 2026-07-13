# BID-049: new_game() seeds late-game debug progression values

**Category:** code-smell (suspected shipped debug state — progression-breaking)
**Discovered During:** GID-117 / TID-440

## Description

`SaveManager.new_game()` initializes a brand-new save with `xp = 11250`, `level = 15`,
`skill_points = 14`, and `coins = 3000`. A new player therefore starts at level 15 with 14
unspent skill points and a large coin balance, bypassing the entire early progression arc
(XP curve, first skill unlocks, early economy) and contradicting the game's own tutorial
popups ("Coins are the main currency. Earn them by winning battles…", "Skill Points are
earned by leveling up"). Battle coin rewards are ~5 coins (tier-1 `undead_basic`), so 3000
starting coins trivializes the merchant/shop loop for many hours.

## Evidence

- `autoloads/SaveManager.gd` — `new_game()` (around line 376): `xp = 11250`, `level = 15`,
  `skill_points = 14`; `coins = 3000` earlier in the same function.
- `git log -S "11250" --all -- autoloads/SaveManager.gd` resolves only to merge commit
  `e0d4ce9` (PR #290, GID-092 co-op multiplayer bug fixes, 2026-06-24) — consistent with
  test/debug values used while reproducing co-op bugs leaking into main via the merge.
- Contrast: `essence = 0`, `corruption_points = 0`, etc. in the same function all start at
  genuine zero.

## Suggested Resolution

Confirm with the user what the intended new-game baseline is (presumably `xp = 0`,
`level = 1`, `skill_points = 0`, and a small coin float — the pre-GID-092 values can be
recovered from history). Then reset the constants in `new_game()` and verify the scripted
tutorial battles (GID-108) and first-session economy still function from a true level-1
start. Note `new_game()` values are not covered by save migration, so no migration is
needed — only fresh saves are affected.
