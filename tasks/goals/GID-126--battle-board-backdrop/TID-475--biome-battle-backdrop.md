# TID-475: Biome-Aware Battle Backdrop

Goal: [GID-126](goal.md) · Type: agent · Status: done

## Problem

`BattleScene.tscn`'s `Background` was a single `ColorRect` at
`Color(0.1, 0.1, 0.15, 0.95)`. Every battle in the game — grassland skirmish,
midnight hunt, dungeon boss, PvP duel — was fought against the same flat dark
blue.

## Plan

Paint the existing `Background` rect with a `ShaderMaterial` instead of adding
new nodes, so the flat colour stays underneath as the fallback and no scene
layout changes. Drive it from the biome + day/night pair the battle already
holds, and build the imagery out of the terrain tiles and prop sprites the 3-D
world already ships.

## Changes Made

- **`assets/shaders/battle_backdrop.gdshader`** (new, + `.uid`) — one
  `canvas_item` shader painting four bands:
  - *Sky*: vertical gradient, drifting cloud banks from 3-octave fbm, a
    hash-lattice star field that only evaluates when `night > 0`, and a sun/moon
    disc with a halo.
  - *Ridges*: two silhouettes from a 1-D noise profile. `ridge_sharp` folds the
    profile about its midpoint (`1 - |2n-1|`), which is what turns rolling
    grassland hills into scorched spires and alpine peaks from the same
    function. The far range is mixed toward the sky for atmospheric depth.
  - *Skyline props*: a jittered cell layout along the horizon drawing the
    biome's two scatter sprites as flat alpha silhouettes. Each fragment tests
    three cells so neighbours can overlap.
  - *Ground*: the biome's terrain tile in a shallow reciprocal-depth
    perspective, with broad noise mottling, distance haze and a darkened
    foreground.

  Then a light pool over the board, a warm seam along the horizon (which is
  also the board divider), a vignette, and a global `dim` toward the old flat
  colour so cards stay legible.

- **`scenes/battle/BattleBackdrop.gd`** (new) — the `PALETTE` table (one entry
  per biome plus the `NEUTRAL` sentinel) and `apply(rect, biome, is_night)`.
  Sky colours, ridge shape and prop pairs live here; ground, ridge and haze
  *tints* are read from `BiomeDef.GRASS_TINT` / `HILL_TINT`, not restated.

- **`scenes/battle/BattleScene.gd`** — `_setup_backdrop()`, called
  unconditionally from `_ready()` beside the Battlefield Resonance UI.

- **`tools/preview_battle_backdrop.gd`** (new) — renders one PNG per variant so
  the art can be judged without playing a battle. Needs a real or virtual
  display; `anim = 0` makes captures reproducible.

- **`tests/unit/test_battle_backdrop.gd`** (new, 16 tests).

## Judgment Calls

- **Generated, not sourced.** The user offered either. Generating it is what
  lets the backdrop track `battlefield_biome`, and it adds no files to
  `assets/textures/`. Recorded in full in [goal.md](goal.md).

- **`ground_desat`.** The terrain PNGs carry a strong hue of their own — the
  hill side is orange dirt. Multiplying `BiomeDef`'s snow-white mountain tint
  over orange gives orange, not snow, so the shader pulls the sample toward
  grey by a per-biome amount before tinting. That is what lets one 16×16 source
  serve several biomes instead of needing new art per biome.

- **`ground_avg` is measured, not guessed.** The far field fades away from
  texel detail (the PNGs have no mipmaps, so minified sampling shimmers). The
  first version faded to a `vec3(0.62)` constant, which was far too bright for
  the dungeon's stone floor — it put a glowing white band across the horizon.
  `apply()` now averages the 16×16 image on the CPU and passes it in.

- **`NIGHT_GROUND_GAIN`.** The `BiomeDef` tints describe sunlit terrain, so a
  night battlefield kept a noon-bright meadow under a star field. Night scales
  the ground tint to 0.45; sky, ridges and props already carry night colours.

- **Cost.** The sky work (fbm ×3, ridges, props) is inside
  `if (uv.y < horizon)`, so it never runs for the ~62 % of the screen below the
  skyline; the ground branch is a texture fetch plus one noise octave. No
  per-frame CPU work at all — `SCREEN_PIXEL_SIZE` gives the shader its own
  aspect ratio, so there is no uniform to re-push on resize.

## Verification

- Headless import clean (no parse/compile errors).
- Suite: 2289 passed / 0 failed / 1 pending (baseline before this task was
  2273 / 0 / 1).
- All eleven variants rendered through `tools/preview_battle_backdrop.gd` under
  `xvfb-run` with the OpenGL3 driver and inspected, plus full `BattleScene`
  captures to confirm cards read against the busiest backdrops.

## Documentation Updates

`docs/agent/visual-polish.md`, `docs/agent/battle-system.md`, `CLAUDE.md`
(docs table row).
