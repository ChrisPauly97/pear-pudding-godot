## Loops a landmark Sprite3D through its LandmarkFrames (GID-152 / TID-648):
## rune glints on an active waystone, water glints in a mana well, the shrine
## orb's pulse, the blight heart's heartbeat. Swaps `texture` (and refreshes the
## outline shader) so modulate dimming and tints keep working. Free the node
## (`stop`) to settle back on the still frame.
extends Node

const _LandmarkFrames = preload("res://game_logic/LandmarkFrames.gd")
const _SpriteOutline = preload("res://game_logic/SpriteOutline.gd")
const _Self = preload("res://scenes/world/entities/SpriteLoop.gd")

const NODE_NAME := "SpriteLoop"
const FPS: float = 5.0

var _sprite: Sprite3D = null
var _frames: Array[Texture2D] = []
var _fps: float = FPS
var _t: float = 0.0
var _shown: int = -1


## A SpriteLoop for `sprite`'s current texture, or null when it has no frames.
static func for_sprite(sprite: Sprite3D) -> Node:
	return with_frames(sprite, _LandmarkFrames.for_still(sprite.texture), FPS)


## A SpriteLoop playing `frames` on `sprite` at `fps`, or null when there are none.
static func with_frames(sprite: Sprite3D, frames: Array[Texture2D], fps: float) -> Node:
	if frames.is_empty():
		return null
	var loop: _Self = _Self.new()
	loop.name = NODE_NAME
	loop._sprite = sprite
	loop._frames = frames
	loop._fps = fps
	loop._t = randf() * float(frames.size()) / fps  # neighbours don't pulse in step
	return loop


## Plays `frames` once on `sprite`, `frame_time` seconds each, and stays on the
## last (chest lids, doors, the mimic reveal — TID-652). Returns the tween.
static func play_once(sprite: Sprite3D, frames: Array[Texture2D], frame_time: float) -> Tween:
	var tw: Tween = sprite.create_tween()
	for i: int in frames.size():
		if i > 0:
			tw.tween_interval(frame_time)
		tw.tween_callback(_show.bind(sprite, frames[i]))
	return tw


static func _show(sprite: Sprite3D, tex: Texture2D) -> void:
	if is_instance_valid(sprite):
		sprite.texture = tex
		_SpriteOutline.refresh(sprite)


## Adds a loop under `parent` for `sprite` unless one is already there.
static func ensure(parent: Node, sprite: Sprite3D) -> void:
	if sprite == null or parent.has_node(NODE_NAME):
		return
	var loop: Node = for_sprite(sprite)
	if loop != null:
		parent.add_child(loop)


## Stops the loop under `parent` (if any) and restores the still frame.
static func stop(parent: Node) -> void:
	var loop := parent.get_node_or_null(NODE_NAME) as _Self
	if loop == null:
		return
	if is_instance_valid(loop._sprite) and not loop._frames.is_empty():
		loop._sprite.texture = loop._frames[0]
		_SpriteOutline.refresh(loop._sprite)
	loop.queue_free()


func _process(delta: float) -> void:
	if not is_instance_valid(_sprite):
		return
	_t += delta
	var f: int = int(floor(_t * _fps)) % _frames.size()
	if f == _shown:
		return
	_shown = f
	_sprite.texture = _frames[f]
	_SpriteOutline.refresh(_sprite)
