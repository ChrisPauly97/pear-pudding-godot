extends Node3D

var _scroll_id: String = ""
var _player: Node3D = null

# Shared resources — created once across all instances
static var _scroll_mat: StandardMaterial3D
static var _scroll_mesh: CylinderMesh

static func _ensure_shared_resources() -> void:
	if _scroll_mat != null:
		return
	_scroll_mat = StandardMaterial3D.new()
	_scroll_mat.albedo_color = Color(0.85, 0.75, 0.45)
	_scroll_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_scroll_mesh = CylinderMesh.new()
	_scroll_mesh.top_radius = 0.07
	_scroll_mesh.bottom_radius = 0.07
	_scroll_mesh.height = 0.35

func _ready() -> void:
	_ensure_shared_resources()

	var body := MeshInstance3D.new()
	body.mesh = _scroll_mesh
	body.material_override = _scroll_mat
	body.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	body.position = Vector3(0.0, 0.4, 0.0)
	add_child(body)

func setup(scroll_id: String, player_node: Node3D) -> void:
	_scroll_id = scroll_id
	_player = player_node
	if SaveManager.is_scroll_collected(_scroll_id):
		queue_free()

func interact() -> void:
	if SaveManager.is_scroll_collected(_scroll_id):
		return
	SaveManager.mark_scroll_collected(_scroll_id)
	GameBus.story_scroll_collected.emit(_scroll_id)
	AudioManager.play_sfx("scroll_pickup")
	AudioManager.play_narration(_scroll_id)
	_animate_pickup()

## Floats the scroll up and shrinks it away instead of an instant pop
## (TID-427). Tweens the node itself (position/scale) rather than a color
## fade — the mesh material is a shared static resource, so mutating its
## alpha per-instance would fade every scroll in the world at once.
func _animate_pickup() -> void:
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 0.6, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
