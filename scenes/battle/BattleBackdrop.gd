extends RefCounted
## Biome-aware battle backdrop (GID-126 / TID-475).
##
## BattleScene's `Background` node used to be a flat `Color(0.1, 0.1, 0.15)`
## rectangle. `apply()` hands it a `ShaderMaterial` running
## `assets/shaders/battle_backdrop.gdshader`, which paints a graded sky, two
## parallax ridge silhouettes and a perspective ground plane tiled from the
## game's own 16x16 terrain pixel art — no new art assets, no per-frame CPU
## work, and the flat colour still stands as the fallback if the shader is
## missing.
##
## Everything is driven from the biome + day/night pair BattleScene already
## stamps into `GameState` for Battlefield Resonance (GID-059), so the
## backdrop always matches the ground the encounter started on. Puzzle, PvP,
## scripted and dungeon battles carry `battlefield_biome == -1` and get the
## neutral roofed-vault look instead.
##
## Colours are derived from `BiomeDef`'s terrain tints rather than restated, so
## a backdrop can never drift away from the world it depicts — see the
## `ground_gain` note on PALETTE for the one place a scalar is applied.

const _BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const _SHADER = preload("res://assets/shaders/battle_backdrop.gdshader")

const _TEX_GRASS = preload("res://assets/textures/pixel_art/grass_pixel.png")
const _TEX_HILL_SIDE = preload("res://assets/textures/pixel_art/hill_side_pixel.png")
const _TEX_PATH = preload("res://assets/textures/pixel_art/path_pixel.png")
const _TEX_WALL_TOP = preload("res://assets/textures/pixel_art/wall_top_pixel.png")

# Skyline scatter props. One pair per biome, matching BiomeDef.PROP_SETS so the
# backdrop is dressed with exactly what the world scatters on that terrain.
const _PROP_ROCK = preload("res://assets/textures/props/prop_rock.png")
const _PROP_FLOWER = preload("res://assets/textures/props/prop_flower.png")
const _PROP_MUSHROOM = preload("res://assets/textures/props/prop_mushroom.png")
const _PROP_FERN = preload("res://assets/textures/props/prop_fern.png")
const _PROP_CACTUS = preload("res://assets/textures/props/prop_cactus.png")
const _PROP_THORN = preload("res://assets/textures/props/prop_thorn.png")
const _PROP_ASH_PILE = preload("res://assets/textures/props/prop_ash_pile.png")
const _PROP_EMBER = preload("res://assets/textures/props/prop_ember.png")
const _PROP_BOULDER = preload("res://assets/textures/props/prop_boulder.png")
const _PROP_LICHEN = preload("res://assets/textures/props/prop_lichen.png")
const _PROP_BURIAL_MOUND = preload("res://assets/textures/props/burial_mound.png")

## Screen-space skyline. Matches BattleScene.tscn's Divider anchor (0.38), so
## the seam between the two halves of the board reads as the horizon.
const HORIZON: float = 0.38

## Biome id used for battlefields with no world biome (dungeons, named maps,
## puzzles, PvP). Mirrors BattlefieldRules.BIOME_NONE / GameState's default.
const NEUTRAL: int = -1

## Per-biome backdrop description, keyed by `BiomeDef` biome id plus NEUTRAL.
##
## - `ground` — which terrain PNG tiles the ground plane.
## - `ground_gain` — scalar on `BiomeDef.GRASS_TINT`. The world tints multiply
##   a lit 3-D surface; a 2-D backdrop has no light to multiply, so the darker
##   biomes need lifting back into a readable range. This is the only place
##   the shared palette is adjusted.
## - `ground_scale` — how finely the ground art tiles.
## - `ground_desat` — how far the ground art is pulled to grey before the biome
##   tint multiplies it. The terrain PNGs carry a strong hue of their own, so
##   the snowy and ashen biomes have to neutralise it before their tint can
##   land; without this, one source texture could not serve several biomes.
## - `ridge_base` — optional override for the silhouette colour, which is
##   otherwise `BiomeDef.HILL_TINT` for that biome. Only the roofed vault sets
##   it: it has no biome to borrow hills from.
## - `props` — the two scatter sprites silhouetted along the skyline. These are
##   the same pairs `BiomeDef.PROP_SETS` scatters on that terrain in the world.
## - `prop_h` — tallest skyline prop, as a fraction of screen height.
## - `sky_day` / `sky_night` — `[top, horizon]` gradient stops.
## - `ridge_amp` / `ridge_jag` / `ridge_sharp` — silhouette height (fraction of
##   screen height), horizontal frequency, and how far the profile is folded
##   from rolling hills toward peaks: flat dunes through to scorched spires.
## - `celestial` — false for roofed battlefields, which get no sun/moon.
## - `dim` — how far the finished image is pulled toward the old flat colour.
##   The board is drawn on top, so every backdrop is deliberately held back;
##   the already-dark vault needs less of it than a bright meadow.
const PALETTE: Dictionary = {
	_BiomeDef.GRASSLANDS: {
		"ground": _TEX_GRASS,
		"ground_gain": 0.70,
		"ground_desat": 0.10,
		"ground_scale": 3.5,
		"props": [_PROP_ROCK, _PROP_FLOWER],
		"prop_h": 0.026,
		"sky_day": [Color(0.30, 0.55, 0.85), Color(0.72, 0.82, 0.78)],
		"sky_night": [Color(0.04, 0.06, 0.16), Color(0.16, 0.18, 0.34)],
		"ridge_amp": 0.065,
		"ridge_jag": 2.4,
		"ridge_sharp": 0.35,
		"celestial": true,
		"dim": 0.44,
	},
	_BiomeDef.FOREST: {
		"ground": _TEX_GRASS,
		"ground_gain": 1.10,
		"ground_desat": 0.15,
		"ground_scale": 3.5,
		"props": [_PROP_MUSHROOM, _PROP_FERN],
		"prop_h": 0.034,
		"sky_day": [Color(0.24, 0.44, 0.62), Color(0.55, 0.66, 0.52)],
		"sky_night": [Color(0.03, 0.06, 0.10), Color(0.10, 0.17, 0.20)],
		"ridge_amp": 0.085,
		"ridge_jag": 3.6,
		"ridge_sharp": 0.75,
		"celestial": true,
		"dim": 0.40,
	},
	_BiomeDef.DESERT: {
		"ground": _TEX_HILL_SIDE,
		"ground_gain": 1.0,
		"ground_desat": 0.35,
		"ground_scale": 3.0,
		"props": [_PROP_CACTUS, _PROP_THORN],
		"prop_h": 0.036,
		"sky_day": [Color(0.36, 0.62, 0.88), Color(0.95, 0.80, 0.55)],
		"sky_night": [Color(0.05, 0.05, 0.14), Color(0.24, 0.19, 0.30)],
		"ridge_amp": 0.040,
		"ridge_jag": 1.0,
		"ridge_sharp": 0.0,
		"celestial": true,
		"dim": 0.44,
	},
	_BiomeDef.SCORCHED: {
		"ground": _TEX_PATH,
		"ground_gain": 2.4,
		"ground_desat": 0.45,
		"ground_scale": 4.0,
		"props": [_PROP_ASH_PILE, _PROP_EMBER],
		"prop_h": 0.028,
		"sky_day": [Color(0.28, 0.16, 0.16), Color(0.72, 0.30, 0.12)],
		"sky_night": [Color(0.08, 0.03, 0.05), Color(0.38, 0.10, 0.05)],
		"ridge_amp": 0.115,
		"ridge_jag": 4.2,
		"ridge_sharp": 1.0,
		"celestial": true,
		"dim": 0.38,
	},
	_BiomeDef.MOUNTAINS: {
		"ground": _TEX_HILL_SIDE,
		"ground_gain": 1.00,
		"ground_desat": 0.90,
		"ground_scale": 4.5,
		"props": [_PROP_BOULDER, _PROP_LICHEN],
		"prop_h": 0.030,
		"sky_day": [Color(0.30, 0.50, 0.80), Color(0.78, 0.84, 0.92)],
		"sky_night": [Color(0.03, 0.05, 0.15), Color(0.14, 0.20, 0.32)],
		"ridge_amp": 0.155,
		"ridge_jag": 4.0,
		"ridge_sharp": 1.0,
		"celestial": true,
		"dim": 0.44,
	},
	NEUTRAL: {
		# A roofed vault: no sun, no sky, broken stonework for a skyline and
		# grave mounds along it. Used by dungeons, named maps, puzzles and PvP.
		"ground": _TEX_WALL_TOP,
		"ground_gain": 0.9,
		"ground_desat": 0.55,
		"ground_scale": 4.5,
		"ridge_base": Color(0.30, 0.26, 0.34),
		"props": [_PROP_BURIAL_MOUND, _PROP_BOULDER],
		"prop_h": 0.030,
		"sky_day": [Color(0.06, 0.05, 0.10), Color(0.20, 0.16, 0.26)],
		"sky_night": [Color(0.05, 0.04, 0.09), Color(0.17, 0.13, 0.23)],
		"ridge_amp": 0.065,
		"ridge_jag": 5.0,
		"ridge_sharp": 1.0,
		"celestial": false,
		"dim": 0.26,
	},
}

## Ground tint multiplier after dark. The BiomeDef tints describe sunlit
## terrain; without this a night battlefield keeps a noon-bright meadow under a
## star field. The sky, ridges and props already carry their own night colours.
const NIGHT_GROUND_GAIN: float = 0.45

## Warm key light pooled over the board and glowing along the divider seam.
const GLOW_TINT: Color = Color(1.00, 0.85, 0.45)

## What `dim` pulls toward — the flat colour BattleScene.tscn still ships as
## the no-shader fallback, so the two readings of the scene stay related.
const DIM_COLOR: Color = Color(0.10, 0.10, 0.15)


## Returns the PALETTE entry for `biome`, falling back to the neutral vault for
## any id outside 0..BiomeDef.COUNT-1 (including the -1 no-biome sentinel).
static func palette_for(biome: int) -> Dictionary:
	return PALETTE.get(biome, PALETTE[NEUTRAL]) as Dictionary


## Paints `bg` with the backdrop for `biome` at the given time of day.
##
## `bg` keeps its flat `color` underneath, so a failed shader load or a
## stripped material degrades to exactly the old look. Pass `animate = false`
## to freeze the shader clock — the preview tool and the tests rely on that to
## get a reproducible frame.
static func apply(bg: ColorRect, biome: int, is_night: bool, animate: bool = true) -> void:
	if bg == null:
		return
	var entry: Dictionary = palette_for(biome)
	var sky: Array = entry["sky_night"] if is_night else entry["sky_day"]

	var props: Array = entry["props"]
	var mat := ShaderMaterial.new()
	mat.shader = _SHADER
	mat.set_shader_parameter("ground_tex", entry["ground"])
	mat.set_shader_parameter("prop_a_tex", props[0])
	mat.set_shader_parameter("prop_b_tex", props[1])
	mat.set_shader_parameter("sky_top", _rgb(sky[0]))
	mat.set_shader_parameter("sky_horizon", _rgb(sky[1]))
	# Both ranges take the biome's hill tint — the same palette ChunkRenderer
	# paints its hills with — the nearer one darkened, since the shader fades
	# only the far range toward the sky for atmospheric depth.
	var ridge: Color = entry.get("ridge_base", _BiomeDef.HILL_TINT[_clamped(biome)])
	mat.set_shader_parameter("ridge_far", _rgb(ridge))
	mat.set_shader_parameter("ridge_near", _rgb(ridge * 0.35))
	var ground_gain: float = float(entry["ground_gain"]) \
		* (NIGHT_GROUND_GAIN if is_night else 1.0)
	mat.set_shader_parameter("ground_tint",
		_rgb(_BiomeDef.GRASS_TINT[_clamped(biome)] * ground_gain))
	mat.set_shader_parameter("glow_tint", _rgb(GLOW_TINT))
	mat.set_shader_parameter("dim_color", _rgb(DIM_COLOR))
	mat.set_shader_parameter("horizon", HORIZON)
	mat.set_shader_parameter("ridge_amp", float(entry["ridge_amp"]))
	mat.set_shader_parameter("ridge_jag", float(entry["ridge_jag"]))
	mat.set_shader_parameter("ridge_sharp", float(entry["ridge_sharp"]))
	mat.set_shader_parameter("prop_h", float(entry["prop_h"]))
	mat.set_shader_parameter("ground_scale", float(entry["ground_scale"]))
	mat.set_shader_parameter("ground_desat", float(entry["ground_desat"]))
	mat.set_shader_parameter("ground_avg", _mean_rgb(entry["ground"], float(entry["ground_desat"])))
	mat.set_shader_parameter("night", 1.0 if is_night else 0.0)
	mat.set_shader_parameter("celestial", 1.0 if bool(entry["celestial"]) else 0.0)
	mat.set_shader_parameter("dim", float(entry["dim"]))
	mat.set_shader_parameter("anim", 1.0 if animate else 0.0)
	bg.material = mat


## Mean colour of a ground texture, desaturated the same way the shader
## desaturates its samples, as a Vector3. The far field fades to this rather
## than to the aliased texel soup a minified 16x16 tile would give — measuring
## it beats guessing a constant, which was visibly too bright for stone floors
## and too dark for snow. These are 16x16 sources, so the scan is trivial.
static func _mean_rgb(tex: Texture2D, desat: float) -> Vector3:
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.get_width() == 0 or img.get_height() == 0:
		return Vector3(0.5, 0.5, 0.5)
	var acc := Vector3.ZERO
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			acc += Vector3(c.r, c.g, c.b)
	var mean: Vector3 = acc / float(img.get_width() * img.get_height())
	var luma: float = mean.dot(Vector3(0.299, 0.587, 0.114))
	return mean.lerp(Vector3(luma, luma, luma), clampf(desat, 0.0, 1.0))


## Biome id clamped into the BiomeDef tint arrays. The neutral battlefield has
## no world biome, so it borrows the mountains' cold stone tints.
static func _clamped(biome: int) -> int:
	return clampi(biome, 0, _BiomeDef.COUNT - 1) if biome >= 0 else _BiomeDef.MOUNTAINS


## Color -> Vector3, saturated. Shader colour uniforms are vec3; Color carries
## an alpha the shader has no use for, and the * gain above can overshoot 1.
static func _rgb(c: Color) -> Vector3:
	return Vector3(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0))
