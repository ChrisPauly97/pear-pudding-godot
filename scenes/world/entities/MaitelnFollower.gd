extends Node3D

## Maiteln's travelling companion avatar (GID-108 / TID-403). Follows the player
## on story-mode named maps and at the TID-402 wilderness camp. Distinct from
## the battle companion system (data/companions/maiteln.tres) — this is purely
## a visual/narrative presence. WorldScene owns all spawn/despawn gating
## (see _maiteln_should_be_present()); this script only moves and answers taps.

const TextureGen = preload("res://game_logic/TextureGen.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _AvatarSync = preload("res://game_logic/net/AvatarSync.gd")
const ObjectiveTracker = preload("res://game_logic/ObjectiveTracker.gd")

## Offset from the player's position, in world units — keeps him visibly beside
## the player without overlapping the player sprite or blocking the view.
const _FOLLOW_OFFSET := Vector3(-1.4, 0.0, -1.4)
const _FOLLOW_RATE: float = 6.0
## ~8 tiles squared — past this, treat the gap as a teleport (map transition,
## fast travel, door) rather than something to smoothly walk across.
const _SNAP_DISTANCE_SQ: float = 64.0
## Below this squared distance-to-target, treat him as "arrived" (idle) rather
## than perpetually inching forward and animating a walk that's really a settle.
const _MOVE_EPS_SQ: float = 0.0004
const ANIM_FPS: float = 6.0

## One flavor line per ObjectiveTracker label, in Maiteln's register (matches
## the TID-402 rabbit-hunt tutorial popup tone). "" / unmapped falls back to
## _FALLBACK_LINE.
const _LINES_BY_OBJECTIVE: Dictionary = {
	"Leave Madrian": "Best we're away before your master wakes, lad.",
	"Make camp for the night": "Rain's comin' in. We'll not get a fire lit tonight — best find somethin' to eat.",
	"Learn to make fire": "Flint and tinder, patience and a steady hand. I'll show ye proper, come mornin'.",
	"Find Lord Farsyth": "Farsyth's an old friend. He'll want to hear what's comin' from Martarquas way.",
	"Encounter Isfig": "That lass again. Mind yourself — she fights harder each time.",
	"Reach Blancogov": "Blancogov by dusk, if the roads hold. The King will want more than a letter.",
	"Enter the Temple": "Through those gates lies the whole council, lad. Speak plain, and speak true.",
}
const _FALLBACK_LINE: String = "Keep your wits about ye — the road's long yet."

var _player_ref: Node3D = null
var world_scene: Node3D = null  # set via setup(); mirrors RemotePlayer.world_scene

var _sprite: AnimatedSprite3D = null   # non-null when SpriteRegistry art + walk frames are available
var _static_sprite: Sprite3D = null    # fallback when the registry/walk frames are missing
var _is_moving: bool = false

## Co-op (GID-108 / TID-408, design rule 4): exactly one Maiteln per session. The
## authority's copy runs the normal follow-the-player logic below and broadcasts
## its resulting position; every other client's copy is "networked" — it ignores
## _player_ref entirely and just lerps toward the last position fed by
## set_net_state(), so there is only ever one authoritative Maiteln, not one per
## client. WorldScene owns the map-filter/visibility decision (CLAUDE.md
## cross-map-ghost invariant), not this script.
var _networked: bool = false
var _net_target: Vector3 = Vector3.ZERO

func setup(player_node: Node3D, world_scene_ref: Node3D) -> void:
	_player_ref = player_node
	world_scene = world_scene_ref
	if is_instance_valid(_player_ref):
		position = _player_ref.position + _FOLLOW_OFFSET

func set_networked(v: bool) -> void:
	_networked = v
	if v:
		_net_target = position

## Fed by WorldScene when a co-op position packet arrives (authority → client only).
func set_net_state(x: float, z: float) -> void:
	_net_target = Vector3(x, position.y, z)

func _ready() -> void:
	var tex: Texture2D = _SpriteRegistry.maiteln_texture()
	var walk_frames: Array[Texture2D] = _SpriteRegistry.maiteln_walk_frames() if tex != null else []
	if tex != null and walk_frames.size() == 4:
		_sprite = _build_animated_sprite(tex, walk_frames)
		add_child(_sprite)
	else:
		_static_sprite = Sprite3D.new()
		if tex != null:
			_SpriteRegistry.setup_sprite(_static_sprite, tex)
		else:
			_static_sprite.texture = TextureGen.npc_maiteln()
			_static_sprite.pixel_size = 0.04
			_static_sprite.position = Vector3(0.0, 0.69, 0.0)
		_static_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_static_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		_static_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(_static_sprite)

	var lbl := Label3D.new()
	lbl.text = "Maiteln"
	lbl.font_size = 32
	lbl.pixel_size = 0.025
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 2.0, 0.0)
	lbl.modulate = Color(0.75, 0.85, 1.0)
	add_child(lbl)

## Builds an idle/walk AnimatedSprite3D from one idle frame + 4 walk frames,
## mirroring AvatarSprite.build()'s pattern (BID-051: Maiteln is the only
## non-player entity that visibly moves, so he's the only one worth animating).
func _build_animated_sprite(idle_tex: Texture2D, walk_frames: Array[Texture2D]) -> AnimatedSprite3D:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", ANIM_FPS)
	sf.add_frame("idle", idle_tex)
	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", ANIM_FPS)
	for frame in walk_frames:
		sf.add_frame("walk", frame)
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var anim := AnimatedSprite3D.new()
	anim.sprite_frames = sf
	anim.pixel_size = _SpriteRegistry.CHAR_PIXEL_SIZE
	anim.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	anim.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	anim.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	anim.position = Vector3(0.0, float(idle_tex.get_height()) * _SpriteRegistry.CHAR_PIXEL_SIZE * 0.5 + _SpriteRegistry.FEET_MARGIN, 0.0)
	anim.play("idle")
	return anim

func _process(delta: float) -> void:
	if _networked:
		var to_net: Vector3 = _net_target - position
		var net_dist_sq: float = to_net.x * to_net.x + to_net.z * to_net.z
		if net_dist_sq > _SNAP_DISTANCE_SQ:
			position.x = _net_target.x
			position.z = _net_target.z
			_set_moving(false, to_net)
		else:
			var net_pos: Vector3 = _AvatarSync.interp(position, _net_target, delta, _FOLLOW_RATE)
			position.x = net_pos.x
			position.z = net_pos.z
			_set_moving(net_dist_sq > _MOVE_EPS_SQ, to_net)
		if world_scene != null and world_scene.has_method("get_terrain_height"):
			position.y = world_scene.get_terrain_height(position.x, position.z)
		return
	if not is_instance_valid(_player_ref):
		return
	var target := Vector3(_player_ref.position.x + _FOLLOW_OFFSET.x, position.y,
		_player_ref.position.z + _FOLLOW_OFFSET.z)
	var to_target: Vector3 = target - position
	var target_dist_sq: float = to_target.x * to_target.x + to_target.z * to_target.z
	if target_dist_sq > _SNAP_DISTANCE_SQ:
		position.x = target.x
		position.z = target.z
		_set_moving(false, to_target)
	else:
		var new_pos: Vector3 = _AvatarSync.interp(position, target, delta, _FOLLOW_RATE)
		position.x = new_pos.x
		position.z = new_pos.z
		_set_moving(target_dist_sq > _MOVE_EPS_SQ, to_target)
	if world_scene != null and world_scene.has_method("get_terrain_height"):
		position.y = world_scene.get_terrain_height(position.x, position.z)

## Switches the walk/idle animation and flip_h based on this frame's movement
## toward the target. No-op when running on the static-Sprite3D fallback path.
func _set_moving(moving: bool, to_target: Vector3) -> void:
	_is_moving = moving
	if _sprite == null:
		return
	if moving:
		var screen_x: float = to_target.x - to_target.z
		if abs(screen_x) > 0.1:
			_sprite.flip_h = screen_x < 0.0
		if _sprite.animation != &"walk":
			_sprite.play("walk")
	else:
		if _sprite.animation != &"idle":
			_sprite.play("idle")

## Tap-to-hear-a-line, keyed to the current story objective.
func interact() -> void:
	var flags: Dictionary = SceneManager.save_manager.story_flags
	var obj: Dictionary = ObjectiveTracker.current_objective(flags)
	var label: String = str(obj.get("label", ""))
	var line: String = str(_LINES_BY_OBJECTIVE.get(label, _FALLBACK_LINE))
	GameBus.hud_message_requested.emit(line)
