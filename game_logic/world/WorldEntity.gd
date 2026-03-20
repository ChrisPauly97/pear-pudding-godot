class_name WorldEntity
extends RefCounted

var id: String
var x: float
var z: float  # world Z (Java's Y in 2D map coords)

func _init(p_id: String, p_x: float, p_z: float) -> void:
	id = p_id
	x = p_x
	z = p_z

func distance_to(px: float, pz: float) -> float:
	var dx = x - px
	var dz = z - pz
	return sqrt(dx * dx + dz * dz)

func to_world_pos() -> Vector3:
	return Vector3(x, 0.0, z)
