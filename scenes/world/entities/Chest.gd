extends Node3D

var chest_data: Dictionary = {}
var _opened: bool = false

# Shared material for opened chests — created once, reused by all instances.
static var _opened_mat: StandardMaterial3D

func init_from_data(data: Dictionary) -> void:
	chest_data = data
	_opened = data.get("opened", false)
	if _opened:
		_show_opened()

func mark_opened() -> void:
	_opened = true
	chest_data["opened"] = true
	_show_opened()

func _show_opened() -> void:
	if not _opened_mat:
		_opened_mat = StandardMaterial3D.new()
		_opened_mat.albedo_color = Color(0.4, 0.3, 0.0)
	var mi := find_child("MeshInstance3D", true, false)
	if mi is MeshInstance3D:
		mi.material_override = _opened_mat
