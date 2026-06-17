extends Node3D

const GardenDefs = preload("res://game_logic/GardenDefs.gd")

var plot_idx: int = 0

var _soil: MeshInstance3D
var _plant: MeshInstance3D
var _label: Label3D
var _last_stage: int = -1

static var _soil_mat: StandardMaterial3D
static var _stage1_mat: StandardMaterial3D
static var _stage2_mat: StandardMaterial3D
static var _stage3_mat: StandardMaterial3D
static var _flower_mat: StandardMaterial3D

static func _ensure_mats() -> void:
	if _soil_mat != null:
		return
	_soil_mat = StandardMaterial3D.new()
	_soil_mat.albedo_color = Color(0.45, 0.28, 0.10)
	_soil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stage1_mat = StandardMaterial3D.new()
	_stage1_mat.albedo_color = Color(0.35, 0.70, 0.20)
	_stage1_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stage2_mat = StandardMaterial3D.new()
	_stage2_mat.albedo_color = Color(0.20, 0.65, 0.15)
	_stage2_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stage3_mat = StandardMaterial3D.new()
	_stage3_mat.albedo_color = Color(0.10, 0.55, 0.10)
	_stage3_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flower_mat = StandardMaterial3D.new()
	_flower_mat.albedo_color = Color(0.95, 0.85, 0.10)
	_flower_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func init_from_data(data: Dictionary) -> void:
	plot_idx = int(data.get("plot_idx", 0))

func _ready() -> void:
	_ensure_mats()

	var trough_mesh := BoxMesh.new()
	trough_mesh.size = Vector3(0.9, 0.1, 0.9)
	_soil = MeshInstance3D.new()
	_soil.mesh = trough_mesh
	_soil.material_override = _soil_mat
	_soil.position = Vector3(0.0, 0.05, 0.0)
	add_child(_soil)

	var plant_mesh := BoxMesh.new()
	plant_mesh.size = Vector3(0.3, 0.2, 0.3)
	_plant = MeshInstance3D.new()
	_plant.mesh = plant_mesh
	_plant.material_override = _stage1_mat
	_plant.position = Vector3(0.0, 0.2, 0.0)
	add_child(_plant)

	_label = Label3D.new()
	_label.font_size = 22
	_label.pixel_size = 0.020
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0.0, 1.2, 0.0)
	add_child(_label)

	GameBus.plant_harvested.connect(_on_plant_harvested)
	refresh_visual()

func _on_plant_harvested(_idx: int, _count: int) -> void:
	refresh_visual()

func get_growth_stage() -> int:
	var sm: Node = SceneManager.save_manager
	return sm.get_plot_growth_stage(plot_idx)

func get_plot_data() -> Dictionary:
	var sm: Node = SceneManager.save_manager
	if plot_idx < 0 or plot_idx >= sm.garden_plots.size():
		return {}
	return sm.garden_plots[plot_idx]

func refresh_visual() -> void:
	var sm: Node = SceneManager.save_manager
	var plot: Dictionary = get_plot_data()
	var stage: int
	if plot.is_empty():
		stage = 0
	else:
		stage = sm.get_plot_growth_stage(plot_idx)
	if stage == _last_stage:
		return
	_last_stage = stage
	_apply_stage(stage, plot)

func _apply_stage(stage: int, plot: Dictionary) -> void:
	match stage:
		0:
			_plant.hide()
			_label.text = "Empty plot"
			_label.modulate = Color(0.7, 0.7, 0.7)
		1:
			_plant.show()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.25, 0.25, 0.25)
			_plant.mesh = pm
			_plant.material_override = _stage1_mat
			_plant.position = Vector3(0.0, 0.225, 0.0)
			var seed_id: String = str(plot.get("seed_id", ""))
			var sname: String = str(GardenDefs.SEEDS.get(seed_id, {}).get("display_name", seed_id))
			_label.text = sname + " (early)"
			_label.modulate = Color(0.6, 0.9, 0.4)
		2:
			_plant.show()
			var pm2 := BoxMesh.new()
			pm2.size = Vector3(0.30, 0.45, 0.30)
			_plant.mesh = pm2
			_plant.material_override = _stage2_mat
			_plant.position = Vector3(0.0, 0.325, 0.0)
			var seed_id2: String = str(plot.get("seed_id", ""))
			var sname2: String = str(GardenDefs.SEEDS.get(seed_id2, {}).get("display_name", seed_id2))
			_label.text = sname2 + " (growing)"
			_label.modulate = Color(0.4, 0.9, 0.3)
		3:
			_plant.show()
			var pm3 := BoxMesh.new()
			pm3.size = Vector3(0.30, 0.60, 0.30)
			_plant.mesh = pm3
			_plant.material_override = _stage3_mat
			_plant.position = Vector3(0.0, 0.40, 0.0)

			var flower := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.20, 0.18, 0.20)
			flower.mesh = fm
			flower.material_override = _flower_mat
			flower.position = Vector3(0.0, 0.79, 0.0)
			add_child(flower)

			var seed_id3: String = str(plot.get("seed_id", ""))
			var sname3: String = str(GardenDefs.SEEDS.get(seed_id3, {}).get("display_name", seed_id3))
			_label.text = sname3 + " (ready!)"
			_label.modulate = Color(0.9, 0.95, 0.2)
