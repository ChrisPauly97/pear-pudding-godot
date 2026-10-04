## A Pear Pudding legend riddle spot (GID-153 / TID-655): plain scenery with no
## marker. Interacting asks the `legend` world module what happens.
extends Node3D

const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

var spot_id: String = ""
var _on_interact: Callable
var _sprite: Sprite3D


func setup(id: String, tex: Texture2D, world_height: float, on_interact: Callable) -> void:
	spot_id = id
	_on_interact = on_interact
	_sprite = Sprite3D.new()
	_SpriteRegistry.apply_billboard_flags(_sprite)
	_SpriteRegistry.setup_sprite_height(_sprite, tex, world_height)
	add_child(_sprite)


func set_texture(tex: Texture2D, world_height: float) -> void:
	if _sprite != null:
		_SpriteRegistry.setup_sprite_height(_sprite, tex, world_height)


func interact() -> void:
	if _on_interact.is_valid():
		_on_interact.call(spot_id, "interact")
