extends Node3D

const CardRegistry = preload("res://autoloads/CardRegistry.gd")

var card_id: String = ""
var _rarity: String = "common"
var _rolled_attack: int = -1
var _rolled_health: int = -1
var _rolled_cost: int = -1
var _collected: bool = false
var _landed: bool = false
var _player_nearby: bool = false
var _bob_time: float = 0.0
var _prompt_label: Label3D = null

# Coin mode
var _is_coin: bool = false
var _coin_amount: int = 0
var _pickup_area: Area3D = null

# ── Public setup ────────────────────────────────────────────────────────────

func setup(cid: String, start_pos: Vector3, land_pos: Vector3, p_rarity: String = "common", p_attack: int = -1, p_health: int = -1, p_cost: int = -1) -> void:
	card_id = cid
	_rarity = p_rarity
	_rolled_attack = p_attack
	_rolled_health = p_health
	_rolled_cost = p_cost
	global_position = start_pos
	_build_visual()
	_play_arc(start_pos, land_pos)

func setup_coin(amount: int, start_pos: Vector3, land_pos: Vector3) -> void:
	_is_coin = true
	_coin_amount = amount
	global_position = start_pos
	_build_coin_visual()
	_play_arc(start_pos, land_pos)

# ── Rarity helpers ──────────────────────────────────────────────────────────

func _get_glow_color() -> Color:
	match _rarity:
		"common":
			return Color(0.85, 0.85, 0.85)
		"rare":
			return Color(0.25, 0.45, 1.0)
		"epic":
			return Color(0.7, 0.2, 1.0)
		"legendary":
			return Color(1.0, 0.80, 0.0)
		_:
			return Color(0.85, 0.85, 0.85)

# ── Visual construction ─────────────────────────────────────────────────────

func _build_visual() -> void:
	var tmpl: Dictionary = CardRegistry.get_template(card_id)
	var card_color: Color = tmpl.get("color", Color.WHITE)
	var card_name: String = tmpl.get("name", card_id)

	# Card body — thin flat box in card proportions
	# Emission feeds the bloom post-process so the card visibly glows.
	# (All geometry in this game is unshaded so OmniLight3D has no effect.)
	var glow_color: Color = _get_glow_color()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = card_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 2.5

	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.40, 0.03)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	add_child(mi)

	# Glow halo ring — flat cylinder behind the card so the rarity colour bleeds out
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = glow_color
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.emission_enabled = true
	halo_mat.emission = glow_color
	halo_mat.emission_energy_multiplier = 3.5
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(0.7, 0.7)
	var halo_mi := MeshInstance3D.new()
	halo_mi.mesh = halo_mesh
	halo_mi.material_override = halo_mat
	halo_mi.position = Vector3(0, 0, -0.05)
	add_child(halo_mi)

	# Light beam — tall thin quad that fades out toward the top, always faces camera
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = glow_color
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.emission_enabled = true
	beam_mat.emission = glow_color
	beam_mat.emission_energy_multiplier = 2.0
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	beam_mat.grow = true
	var beam_grad := Gradient.new()
	beam_grad.set_color(0, Color(glow_color.r, glow_color.g, glow_color.b, 0.7))
	beam_grad.set_color(1, Color(glow_color.r, glow_color.g, glow_color.b, 0.0))
	var beam_tex := GradientTexture2D.new()
	beam_tex.gradient = beam_grad
	beam_tex.fill = GradientTexture2D.FILL_LINEAR
	beam_tex.fill_from = Vector2(0.5, 1.0)
	beam_tex.fill_to   = Vector2(0.5, 0.0)
	beam_mat.albedo_texture = beam_tex
	var beam_mesh := QuadMesh.new()
	beam_mesh.size = Vector2(0.18, 4.0)
	var beam_mi := MeshInstance3D.new()
	beam_mi.mesh = beam_mesh
	beam_mi.material_override = beam_mat
	beam_mi.position = Vector3(0, 2.25, -0.06)
	add_child(beam_mi)

	# Card name label (billboard, always faces camera)
	var name_lbl := Label3D.new()
	name_lbl.text = card_name
	name_lbl.pixel_size = 0.004
	name_lbl.position = Vector3(0, 0.42, 0)
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.modulate = Color.WHITE
	add_child(name_lbl)

	# "Press E" prompt shown only for rare / legendary when player is near
	_prompt_label = Label3D.new()
	_prompt_label.text = "Press E"
	_prompt_label.pixel_size = 0.004
	_prompt_label.position = Vector3(0, 0.62, 0)
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.modulate = Color(1.0, 1.0, 0.5)
	_prompt_label.hide()
	add_child(_prompt_label)

	# Pickup detection area — monitoring disabled until arc lands
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	col.shape = sphere
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	area.monitoring = false
	_pickup_area = area
	add_child(area)

	set_process_unhandled_input(true)

func _build_coin_visual() -> void:
	# Gold coin disc — flat cylinder with strong emission for bloom
	var coin_color: Color = Color(1.0, 0.82, 0.1)
	var coin_glow: Color  = Color(1.0, 0.65, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = coin_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = coin_glow
	mat.emission_energy_multiplier = 3.0

	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.18
	cm.height = 0.06
	cm.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	# Tilt the coin so it shows its face
	mi.rotation_degrees = Vector3(80.0, 0.0, 0.0)
	add_child(mi)

	# Large billboard glow halo behind coin — same approach as cards
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = coin_glow
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.emission_enabled = true
	halo_mat.emission = coin_glow
	halo_mat.emission_energy_multiplier = 4.0
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(0.65, 0.65)
	var halo_mi := MeshInstance3D.new()
	halo_mi.mesh = halo_mesh
	halo_mi.material_override = halo_mat
	halo_mi.position = Vector3(0, 0, -0.04)
	add_child(halo_mi)

	# Coin amount label
	var amt_lbl := Label3D.new()
	amt_lbl.text = "+%d" % _coin_amount
	amt_lbl.pixel_size = 0.005
	amt_lbl.position = Vector3(0, 0.38, 0)
	amt_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	amt_lbl.modulate = Color(1.0, 0.9, 0.2)
	add_child(amt_lbl)

	# Pickup detection area (coins auto-collect) — monitoring disabled until arc lands
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	col.shape = sphere
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	area.monitoring = false
	_pickup_area = area
	add_child(area)

# ── Arc animation ───────────────────────────────────────────────────────────

func _play_arc(start_pos: Vector3, land_pos: Vector3) -> void:
	var peak_y: float = start_pos.y + 2.5
	var land_y: float = land_pos.y + 0.25

	# XZ movement: linear to landing spot
	var xz_tween := create_tween()
	xz_tween.set_parallel(true)
	xz_tween.tween_property(self, "global_position:x", land_pos.x, 0.5)
	xz_tween.tween_property(self, "global_position:z", land_pos.z, 0.5)

	# Y movement: up to peak then down to land height
	var y_tween := create_tween()
	y_tween.tween_property(self, "global_position:y", peak_y, 0.25)
	y_tween.tween_property(self, "global_position:y", land_y, 0.25)
	y_tween.tween_callback(func() -> void: _landed = true)
	y_tween.tween_interval(0.5)
	y_tween.tween_callback(func() -> void:
		if _pickup_area:
			_pickup_area.monitoring = true
	)

# ── Per-frame spin after landing ─────────────────────────────────────────────

func _process(delta: float) -> void:
	if _landed and not _collected:
		rotation_degrees.y += delta * 60.0
	# Input.action_press() (virtual buttons) doesn't generate InputEvents, so
	# _unhandled_input never fires for them. Poll directly here so mobile works.
	if _player_nearby and not _collected and not _is_coin and _rarity != "common":
		if Input.is_action_just_pressed("interact"):
			_collect()
			get_viewport().set_input_as_handled()

# ── Pickup logic ─────────────────────────────────────────────────────────────

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = true
	if _is_coin or _rarity == "common":
		_collect()
	else:
		if _prompt_label:
			_prompt_label.show()

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = false
	if _prompt_label:
		_prompt_label.hide()

func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and not _collected and event.is_action_pressed("interact"):
		_collect()
		get_viewport().set_input_as_handled()

func _collect() -> void:
	if _collected:
		return
	_collected = true
	if _prompt_label:
		_prompt_label.hide()
	if _is_coin:
		SceneManager.save_manager.add_coins(_coin_amount)
	else:
		SceneManager.save_manager.grant_card_reward(card_id, _rarity, _rolled_attack, _rolled_health, _rolled_cost)
	# Disable collision before tweening — physics can't invert a zero-scale basis
	var col := find_child("CollisionShape3D", true, false) as CollisionShape3D
	if col:
		col.disabled = true
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(0.001, 0.001, 0.001), 0.18)
	t.tween_callback(queue_free)
