## Plays walk frames on a parent's Sprite3D billboards while the parent moves
## (GID-152 / TID-645). Speed is read from the parent's global position each
## frame, so it animates chase steps, co-op interpolation and scripted moves
## alike. Swapping `texture` keeps every Sprite3D consumer working (fades,
## idle bob, tints); the outline shader is refreshed on each swap.
extends Node

const _WalkCycleMath = preload("res://game_logic/WalkCycleMath.gd")
const _SpriteOutline = preload("res://game_logic/SpriteOutline.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _Self = preload("res://scenes/world/entities/WalkCycle.gd")

var _tracks: Array[Dictionary] = []  # {"sprite", "idle", "frames"}
var _state: Dictionary = {}
var _last_pos: Vector3 = Vector3.INF
var _shown: int = -1


## A WalkCycle named `node_name` driving `sprite` with its registry walk frames.
static func for_sprite(sprite: Sprite3D, node_name: String) -> Node:
	var wc: _Self = _Self.new()
	wc.name = node_name
	wc.add_sprite(sprite, _SpriteRegistry.walk_frames(sprite.texture))
	return wc


## Animate `sprite` with `frames`; no-op when there are none.
func add_sprite(sprite: Sprite3D, frames: Array[Texture2D]) -> void:
	if sprite == null or frames.is_empty():
		return
	_tracks.append({"sprite": sprite, "idle": sprite.texture, "frames": frames})


func has_tracks() -> bool:
	return not _tracks.is_empty()


func _process(delta: float) -> void:
	var owner3d := get_parent() as Node3D
	if owner3d == null or _tracks.is_empty() or delta <= 0.0:
		return
	var pos: Vector3 = owner3d.global_position if owner3d.is_inside_tree() else owner3d.position
	var flat := Vector3(pos.x - _last_pos.x, 0.0, pos.z - _last_pos.z)
	var speed: float = 0.0 if _last_pos == Vector3.INF else flat.length() / delta
	_last_pos = pos
	var n: int = (_tracks[0]["frames"] as Array).size()
	var f: int = _WalkCycleMath.step(_state, delta, speed, n)
	if f == _shown:
		return
	_shown = f
	for tr: Dictionary in _tracks:
		var spr: Variant = tr["sprite"]
		if not is_instance_valid(spr):
			continue
		var sprite := spr as Sprite3D
		var frames: Array = tr["frames"]
		sprite.texture = tr["idle"] as Texture2D if f < 0 else frames[f % frames.size()] as Texture2D
		_SpriteOutline.refresh(sprite)
