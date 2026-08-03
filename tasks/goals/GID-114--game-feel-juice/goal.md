# GID-114: Game Feel — Audio, Impact & Micro-Interaction Juice

## Objective

Make the game feel satisfying to play by fixing the five biggest feel gaps: total silence, instant battle resolution, ceremony-free world interactions, rigid locomotion, and flat UI micro-interactions.

## Context

A game-feel audit (July 2026) compared the game against the polish staples that make players keep playing, excluding everything already shipped (GID-023 battle numbers/flash/shake, GID-026 battle UX, GID-069 loop friction, GID-070 fades/settings/haptics, GID-084 camera smoothing, GID-089 visual art). Five gaps remained, ranked by impact:

1. **The game is completely silent.** `AudioManager` has full plumbing (8-player SFX pool, music loop hooks, ambience crossfade pair) and ~40 `play_sfx()` call sites exist across battle and world — but `assets/audio/sfx/` contains only a README and no `.wav`/`.ogg` file exists anywhere in the repo. Every sound, ambience, and music hook is a silent no-op. Spec reference: "A satisfying TCG battle loop" (docs/human/specification.md — Goals). Music remains out of scope per spec; SFX and ambient soundscapes are in scope (precedent: GID-070/TID-261 shipped the ambience system).
2. **Battle impacts resolve instantly.** `_execute_attack()` applies damage and calls `_refresh_all()` in the same frame — no attacker lunge, no hit-stop, dead minions vanish on panel rebuild, played cards teleport from hand to board.
3. **World interactions have no ceremony.** Chest open is a material color swap; enemy engage `queue_free()`s the enemy instantly with no alert beat; scroll/dig/door moments resolve with only a toast.
4. **Locomotion is rigid.** `Player.gd` sets velocity directly with zero acceleration/deceleration; footsteps tick a fixed timer decoupled from the walk animation; dust exists only while mounted; landing has no feedback.
5. **UI micro-interactions are default-flat.** No button press feedback or click sound anywhere; drag source card doesn't lift/dim; victory rewards render as static labels; overlays snap open.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-425 | Procedural SFX synthesis & biome ambience (un-mute the game) | agent | done | — |
| TID-426 | Battle impact animation layer: lunge, hit-stop, death & card-travel tweens | agent | done | — |
| TID-427 | World interaction ceremonies: chest open, enemy engage beat, pickup flourishes | agent | done | TID-425 |
| TID-428 | Locomotion feel: accel/decel, walk dust, landing feedback, anim-synced footsteps | agent | done | — |
| TID-429 | UI micro-interactions: button press feedback + click SFX, drag lift, reward count-up | agent | done | TID-425 |

## Acceptance Criteria

- [ ] Every registered SFX key produces an audible, distinct procedurally-synthesized sound; each of the 5 biomes has an audible ambient bed; no external audio assets required; SFX volume setting still applies
- [ ] Player minion attacks show a lunge toward the target with a brief impact beat; minion death animates (shrink/fade) instead of vanishing; playing a card animates it from hand toward its board slot; all animation delays respect the fast-mode battle-speed setting
- [ ] Opening a chest plays a visible open animation with a particle burst; enemy engagement shows an alert beat ("!" indicator + short pause) before the battle transition; scroll pickup and dig success have visible flourishes
- [ ] Player movement accelerates and decelerates smoothly (no single-frame start/stop); walking emits subtle dust; landing after a jump shows dust/squash feedback; footsteps sync to walk animation frames
- [ ] Buttons across HUD and overlays give press feedback (scale/color) and an audible click; the dragged hand card's source panel dims; victory coin/XP totals count up; feedback respects accessibility toggles (screen shake, haptics)
- [x] All tests pass headless; headless editor import is clean after every task

**Status note (updated 2026-08-03):** headless Godot 4.6 became available
this session (`scripts/setup-dev-env.sh` installed it automatically) — both
previously-blocked checks now pass: `godot --headless --editor --quit`
(clean, no parse/compile errors) and `godot --headless --path . -s
tests/runner.gd` (2355 passed, 0 failed, 1 pending — pre-existing). The 4
test files this goal added (`test_sfx_gen.gd`, `test_battle_fx_impact.gd`,
`test_battle_result_ui_count_up.gd`, `test_ui_fx.gd`) all pass, including
`test_sfx_gen::test_all_keys_return_non_null_stream_with_data`, which
directly exercises the "every SFX key produces real audio" claim in the
first checkbox above (as far as an automated, non-interactive check can —
"audible" and "distinct" to a human ear is still unverified).

The remaining gap is unchanged: a **manual playthrough** (battle
attack/death/card-play; world chest/enemy-engage/scroll/dig/waystone;
locomotion walk/jump/land/mount; UI HUD buttons/overlays/drag/victory
screen) has still not happened in any session — this remote environment has
no interactive display. The 5 feel/UX checkboxes above stay unchecked until
someone actually plays it; only the "tests pass headless" box is honestly
checkable from this session's evidence.
