## CampDressing — set dressing that makes each starter camp look like its name
## (GID-166 / TID-687): the Old Orchard is rows of apple trees, the Grain-Store
## Field a granary with hay and sacks, the North Barrow a burial mound ringed by
## stones, the South Road Wreck an overturned cart...
##
## Pure static data, no autoloads. Props are scenery billboards (no collision)
## drawn by the StarterCamps world module; each camp's ground is kept clear of
## random trees, water and hills (StarterZone.CAMP_CLEAR_RADIUS, read by RealmLayout), so the
## dressing reads cleanly. Sprites: tools/generate_camp_props.py (camp_*.png)
## plus the stock oak / boulder / rock / fern props.
extends RefCounted

const _StarterZone = preload("res://game_logic/world/StarterZone.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

## Generated camp sprites (Android needs explicit preloads).
const _TEXTURES: Dictionary = {
	"apple_tree_0": preload("res://assets/textures/props/camp_apple_tree_0.png"),
	"apple_tree_1": preload("res://assets/textures/props/camp_apple_tree_1.png"),
	"apple_basket": preload("res://assets/textures/props/camp_apple_basket.png"),
	"hay_bale": preload("res://assets/textures/props/camp_hay_bale.png"),
	"grain_sacks": preload("res://assets/textures/props/camp_grain_sacks.png"),
	"granary": preload("res://assets/textures/props/camp_granary.png"),
	"scarecrow": preload("res://assets/textures/props/camp_scarecrow.png"),
	"wheat_sheaf": preload("res://assets/textures/props/camp_wheat_sheaf.png"),
	"barrow_mound": preload("res://assets/textures/props/camp_barrow_mound.png"),
	"standing_stone_0": preload("res://assets/textures/props/camp_standing_stone_0.png"),
	"standing_stone_1": preload("res://assets/textures/props/camp_standing_stone_1.png"),
	"ruin_pillar_0": preload("res://assets/textures/props/camp_ruin_pillar_0.png"),
	"ruin_pillar_1": preload("res://assets/textures/props/camp_ruin_pillar_1.png"),
	"rubble": preload("res://assets/textures/props/camp_rubble.png"),
	"hedge": preload("res://assets/textures/props/camp_hedge.png"),
	"signpost": preload("res://assets/textures/props/camp_signpost.png"),
	"fence_post": preload("res://assets/textures/props/camp_fence_post.png"),
	"tor_rock": preload("res://assets/textures/props/camp_tor_rock.png"),
	"broken_cart": preload("res://assets/textures/props/camp_broken_cart.png"),
	"crate": preload("res://assets/textures/props/camp_crate.png"),
	"barrel": preload("res://assets/textures/props/camp_barrel.png"),
}

## camp id → [[prop key, offset from the camp tile (tiles), world height], ...].
## Offsets keep off the member ring (StarterZone.slot_tile, radius 3).
const LAYOUTS: Dictionary = {
	"grain_store": [
		["granary", Vector2(-1, -6), 3.2], ["hay_bale", Vector2(3, -5), 1.0], ["hay_bale", Vector2(4, -4), 1.0],
		["hay_bale", Vector2(5, 1), 1.0], ["grain_sacks", Vector2(-4, -4), 0.9], ["grain_sacks", Vector2(1, 5), 0.9],
		["scarecrow", Vector2(0, 0), 2.0], ["wheat_sheaf", Vector2(-5, 1), 0.9], ["wheat_sheaf", Vector2(-5, 3), 0.9],
		["fence_post", Vector2(-3, 6), 0.9], ["fence_post", Vector2(4, 6), 0.9],
	],
	"south_field": [
		["scarecrow", Vector2(0, 0), 2.0], ["hay_bale", Vector2(-5, -1), 1.0], ["hay_bale", Vector2(5, 2), 1.0],
		["wheat_sheaf", Vector2(-2, -5), 0.9], ["wheat_sheaf", Vector2(0, -5), 0.9], ["wheat_sheaf", Vector2(2, -5), 0.9],
		["wheat_sheaf", Vector2(-2, 5), 0.9], ["wheat_sheaf", Vector2(1, 5), 0.9], ["wheat_sheaf", Vector2(4, 4), 0.9],
		["fence_post", Vector2(-5, 4), 0.9],
	],
	"north_barrow": [
		["barrow_mound", Vector2(0, -1), 2.2],
		["standing_stone_0", Vector2(-5, -2), 1.7], ["standing_stone_1", Vector2(5, -2), 1.9],
		["standing_stone_1", Vector2(-4, 4), 1.6], ["standing_stone_0", Vector2(4, 4), 1.8],
		["boulder_1", Vector2(-2, -5), 0.9], ["rock_2", Vector2(2, 5), 0.5], ["fern_0", Vector2(6, 1), 0.6],
	],
	"hedge_ruins": [
		["ruin_pillar_0", Vector2(-4, -4), 2.2], ["ruin_pillar_1", Vector2(4, -4), 1.8],
		["ruin_pillar_1", Vector2(-4, 4), 1.8], ["rubble", Vector2(1, 1), 0.7], ["rubble", Vector2(5, 3), 0.7],
		["hedge", Vector2(-1, -6), 1.1], ["hedge", Vector2(2, -6), 1.1], ["hedge", Vector2(-6, 0), 1.1],
		["hedge", Vector2(6, 0), 1.1], ["hedge", Vector2(0, 6), 1.1], ["fern_1", Vector2(3, 5), 0.6],
	],
	"east_copse": [
		["tree_oak_0", Vector2(-5, -3), 3.6], ["tree_oak_1", Vector2(-1, -6), 3.9], ["tree_oak_2", Vector2(4, -5), 3.4],
		["tree_oak_1", Vector2(6, 0), 3.7], ["tree_oak_0", Vector2(4, 5), 3.5], ["tree_oak_2", Vector2(-2, 6), 3.8],
		["tree_oak_0", Vector2(-6, 2), 3.4], ["fern_0", Vector2(-2, -2), 0.6], ["fern_2", Vector2(2, 2), 0.6],
		["fern_1", Vector2(5, -2), 0.6], ["mushroom_0", Vector2(-4, 4), 0.4],
	],
	"west_crossing": [
		["signpost", Vector2(0, 0), 1.9], ["fence_post", Vector2(-5, -2), 0.9], ["fence_post", Vector2(-5, 2), 0.9],
		["fence_post", Vector2(5, -2), 0.9], ["fence_post", Vector2(5, 2), 0.9], ["barrel", Vector2(2, -5), 0.9],
		["crate", Vector2(-2, 5), 0.8], ["rock_1", Vector2(4, 5), 0.5],
	],
	"north_tor": [
		["tor_rock", Vector2(0, -1), 3.2], ["boulder_0", Vector2(-5, -2), 1.2], ["boulder_2", Vector2(5, -3), 1.0],
		["boulder_1", Vector2(-4, 5), 1.1], ["boulder_0", Vector2(5, 4), 0.9], ["rock_0", Vector2(-2, -5), 0.5],
		["rock_3", Vector2(2, 5), 0.5], ["rock_1", Vector2(6, 1), 0.5],
	],
	"south_road": [
		["broken_cart", Vector2(0, 0), 1.6], ["crate", Vector2(-4, -4), 0.8], ["crate", Vector2(-5, -3), 0.8],
		["barrel", Vector2(4, -4), 0.9], ["grain_sacks", Vector2(5, 2), 0.9], ["barrel", Vector2(-2, 5), 0.9],
		["crate", Vector2(3, 5), 0.8],
	],
}

## The orchard is a grid: four rows of apple trees spaced four tiles apart,
## offset by two so no trunk lands on the member ring. Plus a few baskets.
const ORCHARD_SPACING: int = 4
const ORCHARD_HALF: int = 6


## Every prop of camp `camp_id`, as [key, overworld tile position (Vector2, tile
## units, tile centre = +0.5), world height].
static func props_for(camp_id: String) -> Array:
	var camp: Dictionary = camp_def(camp_id)
	if camp.is_empty():
		return []
	var c: Vector2i = camp["tile"]
	var base := Vector2(float(c.x) + 0.5, float(c.y) + 0.5)
	var out: Array = []
	for e: Array in _layout(camp_id):
		var off: Vector2 = e[1]
		out.append([str(e[0]), base + off, float(e[2])])
	return out


## Every camp's props in one list.
static func all_props() -> Array:
	var out: Array = []
	for camp: Dictionary in _StarterZone.CAMPS:
		out.append_array(props_for(str(camp["id"])))
	return out


static func camp_def(camp_id: String) -> Dictionary:
	for camp: Dictionary in _StarterZone.CAMPS:
		if str(camp["id"]) == camp_id:
			return camp
	return {}


static func _layout(camp_id: String) -> Array:
	if camp_id != "old_orchard":
		return LAYOUTS.get(camp_id, []) as Array
	var out: Array = []
	var i: int = 0
	for z: int in range(-ORCHARD_HALF, ORCHARD_HALF + 1, ORCHARD_SPACING):
		for x: int in range(-ORCHARD_HALF, ORCHARD_HALF + 1, ORCHARD_SPACING):
			out.append(["apple_tree_%d" % (i % 2), Vector2(x, z), 3.2 + 0.2 * float(i % 3)])
			i += 1
	for off: Vector2 in [Vector2(0, 0), Vector2(-4, 1), Vector2(1, -4)]:
		out.append(["apple_basket", off, 0.7])
	return out


## A prop key's texture: a camp_*.png sprite, or a stock ground prop written
## "<variant key>_<index>" (e.g. "tree_oak_1"). Null if unknown.
static func texture(key: String) -> Texture2D:
	if _TEXTURES.has(key):
		return _TEXTURES[key] as Texture2D
	var cut: int = key.rfind("_")
	if cut <= 0:
		return null
	var v: Array = _SpriteRegistry.prop_variants(key.substr(0, cut))
	var i: int = key.substr(cut + 1).to_int()
	return v[i] as Texture2D if i >= 0 and i < v.size() else null
