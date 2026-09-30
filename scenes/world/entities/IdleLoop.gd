## Blinks and glances a standing NPC's Sprite3D (GID-152 / TID-650) by swapping
## its texture on an IdleLoopMath schedule; the outline shader follows each swap.
## IdleLife's breathe/bob keeps running on the same sprite.
extends Node

const _IdleLoopMath = preload("res://game_logic/IdleLoopMath.gd")
const _IdleFrames = preload("res://game_logic/IdleFrames.gd")
const _SpriteOutline = preload("res://game_logic/SpriteOutline.gd")
const _Self = preload("res://scenes/world/entities/IdleLoop.gd")

var _sprite: Sprite3D = null
var _textures: Array[Texture2D] = []  # [idle, blink, glance]
var _pose: int = _IdleLoopMath.IDLE
var _left: float = 0.0
var _rng := RandomNumberGenerator.new()


## An IdleLoop for `sprite`, or null when its texture has no idle-life frames.
static func for_sprite(sprite: Sprite3D, seed_value: int) -> Node:
	var extra: Array[Texture2D] = _IdleFrames.for_idle(sprite.texture)
	if extra.size() < 2:
		return null
	var loop: _Self = _Self.new()
	loop.name = "IdleLoop"
	loop._sprite = sprite
	loop._textures = [sprite.texture, extra[0], extra[1]]
	loop._rng.seed = seed_value
	loop._left = loop._rng.randf_range(0.0, _IdleLoopMath.HOLD_MAX)  # stagger the first blink
	return loop


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0 or not is_instance_valid(_sprite):
		return
	var nxt: Array = _IdleLoopMath.next(_pose, _rng.randf(), _rng.randf())
	_pose = int(nxt[0])
	_left = float(nxt[1])
	_sprite.texture = _textures[_pose]
	_SpriteOutline.refresh(_sprite)
