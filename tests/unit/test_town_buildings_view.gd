## GID-164 / TID-682: town roofs/trim built off the main thread, shared roof
## materials, one merged trim mesh per town holding every building's trim.
extends "res://tests/framework/test_case.gd"

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _View = preload("res://scenes/world/TownBuildingsView.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _BuildingMesh = preload("res://game_logic/world/BuildingMesh.gd")


func _surface_verts(mesh: ArrayMesh, i: int) -> int:
	if i >= mesh.get_surface_count():
		return 0
	return (mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func test_commit_merges_trim_per_town_and_shares_materials() -> void:
	var ws: _WorldScene = _WorldScene.new()
	var view: _View = _View.new(ws)
	view._build_meshes()
	view._commit()
	var buildings: Array[Dictionary] = RealmLayout.buildings_world()
	assert_gt(buildings.size(), 3)
	assert_eq(view._roofs.size(), buildings.size(), "one roof per building")
	var want: Dictionary = {}  # town → [wood verts, glass verts]
	for b: Dictionary in buildings:
		var t: ArrayMesh = _BuildingMesh.build_trim(b)
		var town: String = str(b["town"])
		var acc: Array = want.get(town, [0, 0])
		acc[0] = int(acc[0]) + _surface_verts(t, 0)
		acc[1] = int(acc[1]) + _surface_verts(t, 1)
		want[town] = acc
	for town: String in want:
		var node := view._root.get_node("Trim_%s" % town) as MeshInstance3D
		assert_not_null(node, "merged trim for %s" % town)
		var acc: Array = want[town]
		assert_eq(_surface_verts(node.mesh as ArrayMesh, 0), int(acc[0]), "%s wood verts" % town)
		assert_eq(_surface_verts(node.mesh as ArrayMesh, 1), int(acc[1]), "%s glass verts" % town)
	var a: MeshInstance3D = view._roofs[0]["roof"]
	var same_style: int = -1
	for i in range(1, view._roofs.size()):
		var ri: Rect2i = view._roofs[i]["rect"]
		if _BuildingMesh.roof_style(ri) == _BuildingMesh.roof_style(view._roofs[0]["rect"] as Rect2i):
			same_style = i
			break
	if same_style > 0:
		var b2: MeshInstance3D = view._roofs[same_style]["roof"]
		assert_true(is_same(a.get_surface_override_material(0), b2.get_surface_override_material(0)),
				"same roof style shares one material")
	view._root.free()
	ws.free()
