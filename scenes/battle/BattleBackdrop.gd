extends RefCounted
## Biome-aware battle backdrop (GID-126 / TID-475, top-down since TID-476).
##
## BattleScene's `Background` node used to be a flat `Color(0.1, 0.1, 0.15)`
## rectangle. `apply()` hands it a `ShaderMaterial` running
## `assets/shaders/battle_backdrop.gdshader`, which paints the patch of ground
## the fight is happening on, seen from directly overhead: the biome's terrain
## art tiled flat, its own scatter props standing on it, and a trodden arena
## under the board with the divider scored across it as a battle line.
##
## The overhead framing is deliberate — the board is a flat layout of cards, so
## a landscape seen edge-on fought it. Nothing here is a horizon.
##
## Everything is driven from the biome + day/night pair BattleScene already
## stamps into `GameState` for Battlefield Resonance (GID-059), so the backdrop
## always matches the ground the encounter started on. Puzzle, PvP, scripted
## and dungeon battles carry `battlefield_biome == -1` and get the neutral
## flagstone-vault look instead.
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

# Scatter props. One pair per biome, matching BiomeDef.PROP_SETS so the board
# is dressed with exactly what the world scatters on that terrain.
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

## Screen-space y of the line between the two halves of the board. Matches
## BattleScene.tscn's Divider anchor (0.38), so the seam the layout already has
## is what gets lit rather than a second line next to it.
const DIVIDER_Y: float = 0.38

## The trodden arena under the board, in viewport fractions. Sized to sit
## inside the card area (which ends at x = 0.86, where the side panel starts)
## with a margin of untouched ground showing around it on every side.
const ARENA_CENTER: Vector2 = Vector2(0.43, 0.50)
const ARENA_HALF: Vector2 = Vector2(0.395, 0.44)
const ARENA_ROUND: float = 0.14

## Biome id used for battlefields with no world biome (dungeons, named maps,
## puzzles, PvP). Mirrors BattlefieldRules.BIOME_NONE / GameState's default.
const NEUTRAL: int = -1

## Per-biome backdrop description, keyed by `BiomeDef` biome id plus NEUTRAL.
##
## - `ground` — which terrain PNG tiles the floor.
## - `ground_gain` — scalar on `BiomeDef.GRASS_TINT`. The world tints multiply
##   a lit 3-D surface; a 2-D backdrop has no light to multiply, so the darker
##   biomes need lifting back into a readable range. This is the only place
##   the shared palette is adjusted.
## - `ground_scale` — tiles of ground art across one screen height.
## - `ground_desat` — how far the ground art is pulled to grey before the biome
##   tint multiplies it. The terrain PNGs carry a strong hue of their own, so
##   the snowy and ashen biomes have to neutralise it before their tint can
##   land; without this, one source texture could not serve several biomes.
## - `props` — the two scatter sprites strewn across the ground. These are the
##   same pairs `BiomeDef.PROP_SETS` scatters on that terrain in the world.
## - `prop_cells` / `prop_density` / `prop_scale` — scatter grid resolution,
##   how many cells hold a prop, and prop height as a fraction of a cell.
##   `prop_scale` must stay ≤ 0.5; the shader relies on it to keep each prop
##   inside its own cell.
## - `light_day` / `light_night` — colour of the light pooled on the arena, the
##   lit battle line, and the faint overall cast.
## - `dim` — how far the finished image is pulled toward the old flat colour.
##   The board is drawn on top, so every backdrop is deliberately held back;
##   the already-dark vault needs less of it than a bright meadow.
const PALETTE: Dictionary = {
	_BiomeDef.GRASSLANDS: {
		"ground": _TEX_GRASS,
		"ground_gain": 0.82,
		"ground_scale": 11.0,
		"ground_desat": 0.10,
		"props": [_PROP_ROCK, _PROP_FLOWER],
		"prop_cells": 5.5,
		"prop_density": 0.42,
		"prop_scale": 0.44,
		"light_day": Color(1.00, 0.94, 0.72),
		"light_night": Color(0.55, 0.68, 1.00),
		"dim": 0.44,
	},
	_BiomeDef.FOREST: {
		"ground": _TEX_GRASS,
		"ground_gain": 1.10,
		"ground_scale": 11.0,
		"ground_desat": 0.15,
		"props": [_PROP_MUSHROOM, _PROP_FERN],
		"prop_cells": 5.0,
		"prop_density": 0.55,
		"prop_scale": 0.46,
		"light_day": Color(0.86, 1.00, 0.74),
		"light_night": Color(0.45, 0.70, 0.88),
		"dim": 0.40,
	},
	_BiomeDef.DESERT: {
		"ground": _TEX_HILL_SIDE,
		"ground_gain": 1.00,
		"ground_scale": 9.0,
		"ground_desat": 0.35,
		"props": [_PROP_CACTUS, _PROP_THORN],
		"prop_cells": 4.5,
		"prop_density": 0.30,
		"prop_scale": 0.48,
		"light_day": Color(1.00, 0.86, 0.55),
		"light_night": Color(0.60, 0.66, 1.00),
		"dim": 0.44,
	},
	_BiomeDef.SCORCHED: {
		"ground": _TEX_PATH,
		"ground_gain": 2.40,
		"ground_scale": 10.0,
		"ground_desat": 0.45,
		"props": [_PROP_ASH_PILE, _PROP_EMBER],
		"prop_cells": 5.5,
		"prop_density": 0.48,
		"prop_scale": 0.42,
		"light_day": Color(1.00, 0.55, 0.25),
		"light_night": Color(1.00, 0.42, 0.18),
		"dim": 0.38,
	},
	_BiomeDef.MOUNTAINS: {
		"ground": _TEX_HILL_SIDE,
		"ground_gain": 1.00,
		"ground_scale": 12.0,
		"ground_desat": 0.90,
		"props": [_PROP_BOULDER, _PROP_LICHEN],
		"prop_cells": 5.0,
		"prop_density": 0.36,
		"prop_scale": 0.46,
		"light_day": Color(0.90, 0.95, 1.00),
		"light_night": Color(0.62, 0.74, 1.00),
		"dim": 0.44,
	},
	NEUTRAL: {
		# A roofed vault: flagstones, grave mounds, torchlight. Used by
		# dungeons, named maps, puzzles and PvP, which carry no world biome.
		"ground": _TEX_WALL_TOP,
		"ground_gain": 1.60,
		"ground_scale": 6.5,
		"ground_desat": 0.55,
		"props": [_PROP_BURIAL_MOUND, _PROP_BOULDER],
		"prop_cells": 5.0,
		"prop_density": 0.28,
		"prop_scale": 0.46,
		"arena_tint": Color(0.26, 0.22, 0.30),
		"light_day": Color(1.00, 0.78, 0.42),
		"light_night": Color(1.00, 0.74, 0.38),
		"dim": 0.26,
	},
}

## Ground and prop brightness after dark. The BiomeDef tints describe sunlit
## terrain; without the ground multiplier a night battlefield keeps a
## noon-bright meadow under a moonlit sky. The props need the same treatment or
## they float over the darkened ground instead of standing on it. The arena,
## light pool and motes carry their own night colours.
const NIGHT_GROUND_GAIN: float = 0.58

## What `dim` pulls toward — the flat colour BattleScene.tscn still ships as
## the no-shader fallback, so the two readings of the scene stay related.
const NIGHT_PROP_LIGHT: float = 0.55
const DAY_PROP_LIGHT: float = 0.95

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
	var props: Array = entry["props"]

	var mat := ShaderMaterial.new()
	mat.shader = _SHADER
	mat.set_shader_parameter("ground_tex", entry["ground"])
	mat.set_shader_parameter("prop_a_tex", props[0])
	mat.set_shader_parameter("prop_b_tex", props[1])

	# The world's own wall/ruin tint is the game's "bare ground" palette —
	# mossy stone, pale sandstone, obsidian, granite — which is exactly what a
	# patch of earth trodden flat by a fight should look like.
	var arena: Color = entry.get("arena_tint", _BiomeDef.WALL_TINT[_clamped(biome)] * 0.55)
	mat.set_shader_parameter("arena_tint", _rgb(arena))
	var ground_gain: float = float(entry["ground_gain"]) \
		* (NIGHT_GROUND_GAIN if is_night else 1.0)
	mat.set_shader_parameter("ground_tint",
		_rgb(_BiomeDef.GRASS_TINT[_clamped(biome)] * ground_gain))
	mat.set_shader_parameter("ground_avg",
		_mean_rgb(entry["ground"], float(entry["ground_desat"])))
	mat.set_shader_parameter("light_tint",
		_rgb(entry["light_night"] if is_night else entry["light_day"]))
	mat.set_shader_parameter("dim_color", _rgb(DIM_COLOR))

	mat.set_shader_parameter("ground_scale", float(entry["ground_scale"]))
	mat.set_shader_parameter("ground_desat", float(entry["ground_desat"]))
	mat.set_shader_parameter("prop_cells", float(entry["prop_cells"]))
	mat.set_shader_parameter("prop_density", float(entry["prop_density"]))
	mat.set_shader_parameter("prop_scale", minf(float(entry["prop_scale"]), 0.5))
	mat.set_shader_parameter("prop_light",
		NIGHT_PROP_LIGHT if is_night else DAY_PROP_LIGHT)

	mat.set_shader_parameter("arena_center", ARENA_CENTER)
	mat.set_shader_parameter("arena_half", ARENA_HALF)
	mat.set_shader_parameter("arena_round", ARENA_ROUND)
	mat.set_shader_parameter("divider", DIVIDER_Y)

	mat.set_shader_parameter("night", 1.0 if is_night else 0.0)
	mat.set_shader_parameter("dim", float(entry["dim"]))
	mat.set_shader_parameter("anim", 1.0 if animate else 0.0)
	bg.material = mat


## Mean colour of a ground texture, desaturated the same way the shader
## desaturates its samples, as a Vector3. Detail fades to this rather than to
## the aliased texel soup a minified 16x16 tile would give — measuring it beats
## guessing a constant, which was visibly too bright for stone floors and too
## dark for snow. These are 16x16 sources, so the scan is trivial.
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
