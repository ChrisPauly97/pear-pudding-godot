## Looping landmark frames (GID-152 / TID-648): the still texture -> four
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
