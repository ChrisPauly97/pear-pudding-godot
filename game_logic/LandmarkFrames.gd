## Looping landmark frames (GID-152 / TID-648, campfires TID-649): the still texture -> four
## frames (frame 1 = the still). One preload per file for Android; regenerate
## with tools/generate_sprites.py (ANIMATED).
extends RefCounted

const _WAYSTONE_ACTIVE := preload("res://assets/textures/props/waystone_active.png")
const _WAYSTONE_ACTIVE_1 := preload("res://assets/textures/props/waystone_active_anim_1.png")
const _WAYSTONE_ACTIVE_2 := preload("res://assets/textures/props/waystone_active_anim_2.png")
const _WAYSTONE_ACTIVE_3 := preload("res://assets/textures/props/waystone_active_anim_3.png")
const _WAYSTONE_ACTIVE_4 := preload("res://assets/textures/props/waystone_active_anim_4.png")
const _MANA_WELL := preload("res://assets/textures/props/mana_well.png")
const _MANA_WELL_1 := preload("res://assets/textures/props/mana_well_anim_1.png")
const _MANA_WELL_2 := preload("res://assets/textures/props/mana_well_anim_2.png")
const _MANA_WELL_3 := preload("res://assets/textures/props/mana_well_anim_3.png")
const _MANA_WELL_4 := preload("res://assets/textures/props/mana_well_anim_4.png")
const _PUZZLE_SHRINE := preload("res://assets/textures/props/puzzle_shrine.png")
const _PUZZLE_SHRINE_1 := preload("res://assets/textures/props/puzzle_shrine_anim_1.png")
const _PUZZLE_SHRINE_2 := preload("res://assets/textures/props/puzzle_shrine_anim_2.png")
const _PUZZLE_SHRINE_3 := preload("res://assets/textures/props/puzzle_shrine_anim_3.png")
const _PUZZLE_SHRINE_4 := preload("res://assets/textures/props/puzzle_shrine_anim_4.png")
const _BLIGHT_HEART := preload("res://assets/textures/props/blight_heart.png")
const _BLIGHT_HEART_1 := preload("res://assets/textures/props/blight_heart_anim_1.png")
const _BLIGHT_HEART_2 := preload("res://assets/textures/props/blight_heart_anim_2.png")
const _BLIGHT_HEART_3 := preload("res://assets/textures/props/blight_heart_anim_3.png")
const _BLIGHT_HEART_4 := preload("res://assets/textures/props/blight_heart_anim_4.png")
## Campfires (TID-649): a burning rest-site fire and the story's smouldering wilderness camp.
const _CAMPFIRE_LIT_1 := preload("res://assets/textures/props/campfire_lit_1.png")
const _CAMPFIRE_LIT_2 := preload("res://assets/textures/props/campfire_lit_2.png")
const _CAMPFIRE_LIT_3 := preload("res://assets/textures/props/campfire_lit_3.png")
const _CAMPFIRE_LIT_4 := preload("res://assets/textures/props/campfire_lit_4.png")
const _CAMPFIRE_LIT_5 := preload("res://assets/textures/props/campfire_lit_5.png")
const _CAMPFIRE_LIT_6 := preload("res://assets/textures/props/campfire_lit_6.png")
const _CAMPFIRE_SMOULDER_1 := preload("res://assets/textures/props/campfire_smoulder_1.png")
const _CAMPFIRE_SMOULDER_2 := preload("res://assets/textures/props/campfire_smoulder_2.png")
const _CAMPFIRE_SMOULDER_3 := preload("res://assets/textures/props/campfire_smoulder_3.png")
const _CAMPFIRE_SMOULDER_4 := preload("res://assets/textures/props/campfire_smoulder_4.png")
## Opening one-shots (TID-652): chest and door swing frames, the mimic reveal.
const _CHEST_AJAR := preload("res://assets/textures/props/chest_ajar.png")
const _CHEST_OPEN := preload("res://assets/textures/props/chest_open.png")
const _DOOR_AJAR := preload("res://assets/textures/props/door_ajar.png")
const _DOOR_OPEN := preload("res://assets/textures/props/door_open.png")
const _MIMIC := preload("res://assets/textures/characters/enemy_mimic.png")

const _TABLE: Dictionary = {
	_WAYSTONE_ACTIVE: [_WAYSTONE_ACTIVE_1, _WAYSTONE_ACTIVE_2, _WAYSTONE_ACTIVE_3, _WAYSTONE_ACTIVE_4],
	_MANA_WELL: [_MANA_WELL_1, _MANA_WELL_2, _MANA_WELL_3, _MANA_WELL_4],
	_PUZZLE_SHRINE: [_PUZZLE_SHRINE_1, _PUZZLE_SHRINE_2, _PUZZLE_SHRINE_3, _PUZZLE_SHRINE_4],
	_BLIGHT_HEART: [_BLIGHT_HEART_1, _BLIGHT_HEART_2, _BLIGHT_HEART_3, _BLIGHT_HEART_4],
}


## The loop frames for a still landmark texture ([] when it has none).
static func for_still(still: Texture2D) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	out.assign(_TABLE.get(still, []) as Array)
	return out


## Campfire loop: burning (6 frames) or smouldering embers + smoke (4 frames).
static func campfire(lit: bool) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if lit:
		out.assign([_CAMPFIRE_LIT_1, _CAMPFIRE_LIT_2, _CAMPFIRE_LIT_3, _CAMPFIRE_LIT_4, _CAMPFIRE_LIT_5,
				_CAMPFIRE_LIT_6])
	else:
		out.assign([_CAMPFIRE_SMOULDER_1, _CAMPFIRE_SMOULDER_2, _CAMPFIRE_SMOULDER_3, _CAMPFIRE_SMOULDER_4])
	return out


## A chest opening: lid lifting on a line of gold light, then thrown back.
static func chest_opening() -> Array[Texture2D]:
	var out: Array[Texture2D] = [_CHEST_AJAR, _CHEST_OPEN]
	return out


## A mimic springing: the lid cracks, then the teeth.
static func mimic_reveal() -> Array[Texture2D]:
	var out: Array[Texture2D] = [_CHEST_AJAR, _MIMIC]
	return out


## A door swinging in on its hinges.
static func door_opening() -> Array[Texture2D]:
	var out: Array[Texture2D] = [_DOOR_AJAR, _DOOR_OPEN]
	return out
