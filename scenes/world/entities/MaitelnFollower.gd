extends Node3D

## Maiteln's travelling companion avatar (GID-108 / TID-403). Follows the player
## on story-mode named maps and at the TID-402 wilderness camp. Distinct from
## the battle companion system (data/companions/maiteln.tres) — this is purely
## a visual/narrative presence. WorldScene owns all spawn/despawn gating
## (see _maiteln_should_be_present()); this script only moves and answers taps.

const TextureGen = preload("res://game_logic/TextureGen.gd")
const _AvatarSync = preload("res://game_logic/net/AvatarSync.gd")
const ObjectiveTracker = preload("res://game_logic/ObjectiveTracker.gd")

## Offset from the player's position, in world units — keeps him visibly beside
## the player without overlapping the player sprite or blocking the view.
const _FOLLOW_OFFSET := Vector3(-1.4, 0.0, -1.4)
const _FOLLOW_RATE: float = 6.0
## ~8 tiles squared — past this, treat the gap as a teleport (map transition,
## fast travel, door) rather than something to smoothly walk across.
const _SNAP_DISTANCE_SQ: float = 64.0

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
	var sprite := Sprite3D.new()
	sprite.texture = TextureGen.npc_maiteln()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.04
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = Vector3(0.0, 0.69, 0.0)
	add_child(sprite)

	var lbl := Label3D.new()
	lbl.text = "Maiteln"
	lbl.font_size = 32
	lbl.pixel_size = 0.025
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 2.0, 0.0)
	lbl.modulate = Color(0.75, 0.85, 1.0)
	add_child(lbl)

func _process(delta: float) -> void:
	if _networked:
		var to_net: Vector3 = _net_target - position
		if to_net.x * to_net.x + to_net.z * to_net.z > _SNAP_DISTANCE_SQ:
			position.x = _net_target.x
			position.z = _net_target.z
		else:
			var net_pos: Vector3 = _AvatarSync.interp(position, _net_target, delta, _FOLLOW_RATE)
			position.x = net_pos.x
			position.z = net_pos.z
		if world_scene != null and world_scene.has_method("get_terrain_height"):
			position.y = world_scene.get_terrain_height(position.x, position.z)
		return
	if not is_instance_valid(_player_ref):
		return
	var target := Vector3(_player_ref.position.x + _FOLLOW_OFFSET.x, position.y,
		_player_ref.position.z + _FOLLOW_OFFSET.z)
	var to_target: Vector3 = target - position
	if to_target.x * to_target.x + to_target.z * to_target.z > _SNAP_DISTANCE_SQ:
		position.x = target.x
		position.z = target.z
	else:
		var new_pos: Vector3 = _AvatarSync.interp(position, target, delta, _FOLLOW_RATE)
		position.x = new_pos.x
		position.z = new_pos.z
	if world_scene != null and world_scene.has_method("get_terrain_height"):
		position.y = world_scene.get_terrain_height(position.x, position.z)

## Tap-to-hear-a-line, keyed to the current story objective.
func interact() -> void:
	var flags: Dictionary = SceneManager.save_manager.story_flags
	var obj: Dictionary = ObjectiveTracker.current_objective(flags)
	var label: String = str(obj.get("label", ""))
	var line: String = str(_LINES_BY_OBJECTIVE.get(label, _FALLBACK_LINE))
	GameBus.hud_message_requested.emit(line)
