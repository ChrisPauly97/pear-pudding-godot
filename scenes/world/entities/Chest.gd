extends Node3D

var chest_data: Dictionary = {}
var _opened: bool = false

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
	# Tint the mesh to show chest is opened
	var mi := find_child("MeshInstance3D", true, false)
	if mi is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.3, 0.0)
		mi.material_override = mat
