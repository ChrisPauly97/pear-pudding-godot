## Display-only representation of another player in the co-op session.
##
## No physics, no input, no camera — driven entirely by interpolated network
## state received via set_net_state(). WorldScene (TID-323) instantiates this,
## calls init_from_data(), then sets world_scene so Y can be recomputed locally.
extends Node3D

const _AvatarSync = preload("res://game_logic/net/AvatarSync.gd")
const _AvatarSprite = preload("res://scenes/world/entities/AvatarSprite.gd")

## The peer's unique network ID. Set by init_from_data().
var peer_id: int = 0

## Reference to WorldScene, set by WorldScene after spawning so we can query
## get_terrain_height(x, z) each frame. May be null before set.
var world_scene: Node3D = null

const _INTERP_RATE: float = 12.0

var _sprite: AnimatedSprite3D
var _target_x: float = 0.0
var _target_z: float = 0.0
var _target_flip_h: bool = false
var _target_moving: bool = false


## Called by WorldScene after instantiation. Expected keys: peer_id, x, z.
func init_from_data(data: Dictionary) -> void:
	peer_id = int(data.get("peer_id", 0))
	_target_x = float(data.get("x", 0.0))
	_target_z = float(data.get("z", 0.0))
	position = Vector3(_target_x, 0.0, _target_z)


func _ready() -> void:
	_sprite = _AvatarSprite.build()
	# Blue tint distinguishes this avatar from the local player's neutral sprite.
	_sprite.modulate = Color(0.7, 0.85, 1.0, 1.0)
	add_child(_sprite)
	_sprite.play("idle")


## Receive latest authoritative state from the peer (called by WorldScene/NetSync).
func set_net_state(x: float, z: float, flip_h: bool, moving: bool) -> void:
	_target_x = x
	_target_z = z
	_target_flip_h = flip_h
	_target_moving = moving


func _process(delta: float) -> void:
	# Interpolate XZ toward the latest received target.
	var target_pos := Vector3(_target_x, position.y, _target_z)
	var new_pos: Vector3 = _AvatarSync.interp(position, target_pos, delta, _INTERP_RATE)

	# Recompute Y locally from terrain — y is never transmitted over the network.
	if world_scene != null and world_scene.has_method("get_terrain_height"):
		new_pos.y = world_scene.get_terrain_height(new_pos.x, new_pos.z)

	position = new_pos

	if _sprite == null:
		return

	_sprite.flip_h = _target_flip_h

	if _target_moving:
		if _sprite.animation != &"walk":
			_sprite.play("walk")
	else:
		if _sprite.animation != &"idle":
			_sprite.play("idle")
