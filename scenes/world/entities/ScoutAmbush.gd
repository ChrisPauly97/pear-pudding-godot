extends Node3D

## Chapter 2 beat 3 — "Scouts in the grass" (GID-108 / TID-407). Same
## tap-to-interact-then-trigger-a-scripted-battle shape as WildernessCamp
## (TID-402), not generalized into a shared base — this codebase already has
## many small single-purpose entity scripts rather than one shared abstraction.

const TextureGen = preload("res://game_logic/TextureGen.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

func _ready() -> void:
	var sprite := Sprite3D.new()
	var tex: Texture2D = _SpriteRegistry.raider_texture()
	if tex != null:
		# 0.04 (below CHAR_PIXEL_SIZE) keeps scouts visibly smaller than
		# full raider EnemyNPCs, matching the old 0.03-vs-0.04 ratio.
		_SpriteRegistry.setup_sprite(sprite, tex, 0.04)
	else:
		sprite.texture = TextureGen.enemy()
		sprite.pixel_size = 0.03
		sprite.position = Vector3(0.0, 0.5, 0.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color(0.55, 0.7, 0.4)
	add_child(sprite)

func interact() -> void:
	GameBus.hud_message_requested.emit(
		"A rustle in the tall grass — Martarquas scouts, closer than they should be. No time to think, only to fight.")
	GameBus.scripted_battle_requested.emit("scout_ambush")
