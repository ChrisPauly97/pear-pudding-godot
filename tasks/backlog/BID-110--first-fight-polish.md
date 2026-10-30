# BID-110: First-fight polish leftovers (TID-798 walkthrough)

**Type:** polish
**Found in:** GID-188 / TID-798

## Context

Rendered walkthrough of the slice's first fight (south field camp, level 1) — fixed the big items in TID-798; these
were noted but left:

- Two tutorial popups back to back on the first engage ("Mana" from `SceneManager._on_enemy_engaged`, then
  "Real-Time Combat" from `BattleOnboarding`). Consider folding the mana line into the real-time popup and
  skipping the `mana` popup in real time.
- Enemy cast label shows a meaningless cost for Heavy Blow: "Casting Heavy Blow (0)"
  (`RealtimeVisuals._update_enemy_cast`; that file sits at the 500-line cap, so drop "(0)" via a helper).
- Floating toasts ("Heavy Blow incoming …") are hard to read over bright grass; give `RealtimeVisuals.toast` a
  backing plate or outline.
