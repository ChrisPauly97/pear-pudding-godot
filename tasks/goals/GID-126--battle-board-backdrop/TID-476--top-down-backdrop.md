# TID-476: Re-frame the Backdrop Overhead

Goal: [GID-126](goal.md) · Type: agent · Status: done

## Problem

Direct user feedback on TID-475 (2026-07-28):

> i think a top down view might be more appropriate for the card battle setup?

Correct. TID-475 built the backdrop as a landscape seen edge-on — sky, horizon,
ridge silhouettes, a ground plane receding to a vanishing point. The board is a
flat arrangement of cards laid out in two rows, so a vista behind it implies a
camera looking *across* a scene the cards are standing up in, which is not what
the layout says. A card mat is a surface you look down at.

## Changes Made

The shader was rewritten rather than parameterised — nothing in the vista
version survives except the noise helpers, the measured `ground_avg` trick, the
vignette and the `dim` hold-back. `assets/shaders/battle_backdrop.gdshader` now
paints, in order:

- **Ground** — the biome tile repeated flat in "square units"
  (`p = vec2(uv.x * aspect, uv.y)`), so tiles stay square on any aspect ratio.
  Per-tile brightness jitter plus broad value noise breaks the period.
- **Arena** — a rounded-rectangle SDF under the board; inside is tinted toward
  bare earth (`BiomeDef.WALL_TINT`) and lifted slightly.
- **Props** — the biome's two scatter sprites on a jittered grid, upright, with
  a soft contact shadow, thinned to a quarter inside the arena.
- **Battle line** — the enemy/player divider scored into the earth: thin lit
  core, wide soft bloom, tapered at both ends.
- **Lighting** — a pool of biome-coloured light on the arena, a faint cast of
  the same light over everything, drifting motes after dark.

`scenes/battle/BattleBackdrop.gd`: `PALETTE` swapped its sky/ridge/celestial
keys for `ground_scale`, `prop_cells`/`prop_density`/`prop_scale` and
`light_day`/`light_night`. `HORIZON` became `DIVIDER_Y` (same 0.38, new
meaning), and `ARENA_CENTER`/`ARENA_HALF`/`ARENA_ROUND` were added.
`NIGHT_PROP_LIGHT` joins `NIGHT_GROUND_GAIN`, which rose 0.45 → 0.58.

`BattleScene.gd` is unchanged — `_setup_backdrop()` still just calls `apply()`.

## Bug Found

**A sampler in a ternary.** The first draft picked between the two prop
sprites with `pick_a ? prop_a_tex : prop_b_tex`, which Godot's shader language
rejects. The suite still passed: a shader that fails to compile *still loads as
a `Resource`* and *still accepts `set_shader_parameter` for anything*, so
`apply()` looked entirely healthy and the scene would silently have shown its
fallback colour in the real game.

Fixed by taking the sampler as a function parameter and calling from both
branches of an `if`. Guarded by a new test — Godot exposes no compile status to
GDScript, but a failed parse registers no uniforms, so
`test_the_shader_actually_compiles` compares
`Shader.get_shader_uniform_list()` against the `uniform` declarations in the
source file. Verified it fails on a deliberately broken shader before keeping
it.

## Judgment Calls

Three approaches were built, looked at, and rejected. They are recorded in
`docs/agent/visual-polish.md` so they do not get reintroduced:

- **Cross-fading a second, rotated sampling of the ground tile** to hide the
  repeat. On anything with strong seams — the dungeon's flagstones especially —
  both grids are visible at once and it reads as a rendering bug. Per-tile hash
  jitter does the same job with one fetch.
- **A stroked arena edge.** A crisp outline reads as a UI frame drawn over the
  ground, not as earth trodden flat. The edge is now a wide soft falloff.
- **Tinting the arena without also lifting it.** On a biome whose bare earth is
  close to its ground colour — sand on sand — the tint alone is invisible, and
  the arena has to read on every biome.

The vista was replaced rather than kept behind a flag: two full art directions
is twice the palette, twice the tuning and twice the test surface for a look
the user has already moved off. It is one commit back in history.

## Cost

The prop layer resolves in **one cell test and one texture fetch**:
`prop_scale ≤ 0.5` plus the jitter bounds keep every prop wholly inside its own
cell, so no neighbour can reach the pixel being shaded. (The vista's skyline
props needed a 3-cell scan, but only over a thin band; a naïve 3×3 scan over a
full screen would not have been acceptable on mobile.) `test_battle_backdrop`
enforces the bound, since exceeding it clips props at cell edges rather than
failing loudly.

Still no per-frame CPU work, and still no uniform to re-push on resize.

## Verification

- Headless import clean.
- Suite: 2291 passed / 0 failed / 1 pending.
- All eleven variants rendered via `tools/preview_battle_backdrop.gd` under
  `xvfb-run`, plus full `BattleScene` captures for grasslands, desert and the
  vault to confirm cards read against the finished art.

## Documentation Updates

`docs/agent/visual-polish.md` (Battle Backdrop section rewritten),
`docs/agent/battle-system.md` (Battlefield Backdrop + test coverage).
