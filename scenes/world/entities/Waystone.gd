extends Node3D

const _WEB = preload("res://scenes/world/entities/WorldEntityBase.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

## Obelisk sprite target height (world units) — a monument, taller than
## the 1.4-unit player but well below boss scale.
const _OBELISK_HEIGHT: float = 1.9

var waystone_data: Dictionary = {}
var _ring: MeshInstance3D = null
var _sprite: Sprite3D = null    # non-null when SpriteRegistry art is available

static var _dormant_mat: StandardMaterial3D
static var _active_mat: StandardMaterial3D
static var _pillar_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _dormant_mat != null:
		return
	_dormant_mat = StandardMaterial3D.new()
	_dormant_mat.albedo_color = Color(0.6, 0.6, 0.65)
	_dormant_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_active_mat = StandardMaterial3D.new()
	_active_mat.albedo_color = Color(1.0, 0.95, 0.3)
	_active_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pillar_mesh = BoxMesh.new()
	_pillar_mesh.size = Vector3(1.0, 1.5, 1.0)

func _ready() -> void:
	add_to_group("interactable")
	_ring = _WEB.build_highlight_ring(self, 0.7)
	var mi: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	var tex: Texture2D = _SpriteRegistry.waystone_texture(bool(waystone_data.get("active", false)))
	if tex != null:
		_sprite = Sprite3D.new()
		_SpriteRegistry.setup_sprite_height(_sprite, tex, _OBELISK_HEIGHT)
		_SpriteRegistry.apply_billboard_flags(_sprite)
		add_child(_sprite)
		if mi:
			mi.visible = false
		return
	_ensure_shared_resources()
	if mi:
		mi.mesh = _pillar_mesh
		mi.material_override = _dormant_mat if not waystone_data.get("active", false) else _active_mat
		mi.position = Vector3(0.0, 0.75, 0.0)

func set_highlighted(on: bool) -> void:
	if _ring != null:
		_ring.visible = on

func init_from_data(data: Dictionary) -> void:
	waystone_data = data
	if data.get("active", false):
		_set_active_visual()

func mark_activated() -> void:
	if waystone_data.get("active", false):
		return
	waystone_data["active"] = true
	_set_active_visual()
	var wid: String = str(waystone_data.get("id", ""))
	SceneManager.save_manager.activate_waystone(wid)
	GameBus.waystone_activated.emit(wid)

func _set_active_visual() -> void:
	if _sprite != null:
		_sprite.texture = _SpriteRegistry.waystone_texture(true)
		return
	_ensure_shared_resources()
	var mi := find_child("MeshInstance3D", true, false)
	if mi is MeshInstance3D:
		(mi as MeshInstance3D).material_override = _active_mat
