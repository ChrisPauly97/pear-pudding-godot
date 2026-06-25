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
var _label: Label3D
var _target_x: float = 0.0
var _target_z: float = 0.0
var _target_flip_h: bool = false
var _target_moving: bool = false

## Identity (TID-342). Defaults until set_identity() delivers the peer's choice;
## the neutral blue keeps the old look for an as-yet-unidentified avatar.
var _display_name: String = ""
var _tint: Color = Color(0.7, 0.85, 1.0, 1.0)


## Called by WorldScene after instantiation. Expected keys: peer_id, x, z.
func init_from_data(data: Dictionary) -> void:
	peer_id = int(data.get("peer_id", 0))
	_target_x = float(data.get("x", 0.0))
	_target_z = float(data.get("z", 0.0))
	position = Vector3(_target_x, 0.0, _target_z)


## Apply the peer's display name + color (TID-342). Safe before or after _ready.
## (Named set_player_identity, not set_identity — Node3D has a native set_identity.)
func set_player_identity(display_name: String, color: Color) -> void:
	_display_name = display_name
	_tint = Color(color.r, color.g, color.b, 1.0)
	_apply_identity()


func _ready() -> void:
	_sprite = _AvatarSprite.build()
	add_child(_sprite)
	_sprite.play("idle")

	# Billboard name tag floating above the sprite's head. no_depth_test keeps it
	# visible over terrain; the top of the sprite is at 2 × its centre Y.
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0008
	_label.outline_size = 12
	_label.modulate = Color.WHITE
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	_label.position = Vector3(0.0, _sprite.position.y * 2.0 + 0.4, 0.0)
	add_child(_label)

	_apply_identity()


## Push the current name/tint onto the sprite + label (no-op before _ready).
func _apply_identity() -> void:
	if _sprite != null:
		_sprite.modulate = _tint
	if _label != null:
		_label.text = _display_name


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
