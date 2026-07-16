extends Node3D

const _WEB = preload("res://scenes/world/entities/WorldEntityBase.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

var door_data: Dictionary = {}
var _ring: MeshInstance3D = null
var _sprite: Sprite3D = null   # non-null when SpriteRegistry art is available
var _is_spire: bool = false    # set by init_from_data(), which runs before _ready()

static var _door_mat: StandardMaterial3D
static var _door_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _door_mat != null:
		return
	_door_mat = StandardMaterial3D.new()
	_door_mat.albedo_color = Color(0.45, 0.28, 0.10)
	_door_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_door_mesh = BoxMesh.new()
	_door_mesh.size = Vector3(1.8, 1.8, 0.1)

func _ready() -> void:
	add_to_group("interactable")
	_ring = _WEB.build_highlight_ring(self, 1.0)

	var tex: Texture2D = _SpriteRegistry.door_texture()
	if tex != null:
		_sprite = Sprite3D.new()
		_SpriteRegistry.setup_sprite(_sprite, tex)
		_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		if _is_spire:
			_sprite.modulate = Color(0.75, 0.45, 1.0)
		add_child(_sprite)
		return

	_ensure_shared_resources()
	var mi: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if mi:
		mi.mesh = _door_mesh
		if _is_spire:
			var spire_mat := StandardMaterial3D.new()
			spire_mat.albedo_color = Color(0.35, 0.10, 0.55)
			spire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = spire_mat
		else:
			mi.material_override = _door_mat
		mi.position = Vector3(0.0, 0.9, 0.0)

func set_highlighted(on: bool) -> void:
	if _ring != null:
		_ring.visible = on

## Runs before _ready() (TerrainMath.spawn_entity() calls it pre-add_child()),
## so it can only set state — the sprite/mesh don't exist yet. _ready() reads
## `_is_spire` once the visual is built, mirroring Chest.gd's `_opened` pattern.
func init_from_data(data: Dictionary) -> void:
	door_data = data
	var target: String = str(data.get("target_map", ""))
	_is_spire = (target == "spire")
	var label_text: String
	if _is_spire:
		label_text = "The Endless Spire"
	elif target.is_empty():
		label_text = "[exit]"
	else:
		label_text = target
	var lbl := Label3D.new()
	lbl.text = label_text
	lbl.font_size = 32
	lbl.pixel_size = 0.02
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 2.4, 0.0)
	lbl.modulate = Color(0.85, 0.50, 1.0) if _is_spire else Color(1.0, 0.85, 0.2)
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	lbl.outline_size = 6
	add_child(lbl)
