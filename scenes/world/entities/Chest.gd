extends Node3D

const _WEB = preload("res://scenes/world/entities/WorldEntityBase.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

var chest_data: Dictionary = {}
var _opened: bool = false
var _ring: MeshInstance3D = null
var _sprite: Sprite3D = null    # non-null when SpriteRegistry art is available
var _lid_hinge: Node3D = null   # fallback-only: procedural hinge-swing lid
const _LID_OPEN_ANGLE: float = -70.0

# Shared across all fallback chest instances — created once
static var _opened_mat: StandardMaterial3D
static var _wood_mat: StandardMaterial3D
static var _gold_mat: StandardMaterial3D
static var _body_mesh: BoxMesh
static var _lock_mesh: BoxMesh
# Shared by every open ceremony (not fallback-only) — building a fresh
# ParticleProcessMaterial per open contributed to the chest-open hitch.
static var _burst_mat: ParticleProcessMaterial

static func _ensure_shared_resources() -> void:
	if _wood_mat != null:
		return
	_wood_mat = StandardMaterial3D.new()
	_wood_mat.albedo_color = Color(0.55, 0.35, 0.10)
	_wood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gold_mat = StandardMaterial3D.new()
	_gold_mat.albedo_color = Color(0.90, 0.75, 0.10)
	_gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_body_mesh = BoxMesh.new()
	_body_mesh.size = Vector3(0.6, 0.4, 0.45)
	_lock_mesh = BoxMesh.new()
	_lock_mesh.size = Vector3(0.1, 0.1, 0.06)

func _ready() -> void:
	add_to_group("interactable")
	_ring = _WEB.build_highlight_ring(self, 0.5)

	# init_from_data() runs before _ready() (TerrainMath.spawn_entity calls it
	# pre-add_child), so `_opened` already reflects the real state (fresh chest
	# = false, save-restored = true) by the time the visual is built below.
	if _SpriteRegistry.chest_closed_texture() != null:
		_sprite = Sprite3D.new()
		_SpriteRegistry.setup_sprite(_sprite, _SpriteRegistry.chest_open_texture() if _opened else _SpriteRegistry.chest_closed_texture())
		_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
		return

	_ensure_shared_resources()

	# Re-use the existing MeshInstance3D (so visibility range from ChunkRenderer sticks)
	var body: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if body:
		body.mesh = _body_mesh
		body.material_override = _wood_mat
		body.position = Vector3(0.0, 0.2, 0.0)

	# Gold lock pip on the front face
	var lock := MeshInstance3D.new()
	lock.mesh = _lock_mesh
	lock.material_override = _gold_mat
	lock.position = Vector3(0.0, 0.2, 0.225)
	add_child(lock)

	_build_lid()
	if _opened:
		_show_opened()

## Lid hinges at the back-top edge of the body so it swings open backward
## like a treasure chest, instead of the body just changing color in place.
func _build_lid() -> void:
	_lid_hinge = Node3D.new()
	_lid_hinge.position = Vector3(0.0, 0.4, -0.225)
	add_child(_lid_hinge)
	var lid := MeshInstance3D.new()
	# Distinct name — _set_opened_material() looks up "MeshInstance3D" by name
	# and must not find this one instead of the body mesh.
	lid.name = "LidMesh"
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.6, 0.08, 0.45)
	lid.mesh = lid_mesh
	lid.material_override = _wood_mat
	lid.position = Vector3(0.0, 0.04, 0.225)
	_lid_hinge.add_child(lid)

func init_from_data(data: Dictionary) -> void:
	chest_data = data
	_opened = data.get("opened", false)
	if _opened:
		_show_opened()

## Called when the player actually opens this chest — full ceremony (lid
## swing, particle burst). Restoring an already-opened chest from a save
## uses `_show_opened()` directly instead, with no animation (TID-427).
func mark_opened() -> void:
	_opened = true
	chest_data["opened"] = true
	_animate_open()

func set_highlighted(on: bool) -> void:
	if _ring != null:
		_ring.visible = on

func _animate_open() -> void:
	if _sprite != null:
		_sprite.texture = _SpriteRegistry.chest_open_texture()
		var tw: Tween = _sprite.create_tween()
		tw.tween_property(_sprite, "scale", Vector3(1.15, 0.85, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sprite, "scale", Vector3.ONE, 0.18)
		_spawn_gold_burst()
		return
	if _lid_hinge != null:
		var hinge_tw: Tween = _lid_hinge.create_tween()
		hinge_tw.tween_property(_lid_hinge, "rotation:x", deg_to_rad(_LID_OPEN_ANGLE), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_gold_burst()
	# Material only — NOT _show_opened(), which would also set the lid's
	# rotation instantly and stomp the tween started above (a Tween reads its
	# "from" value lazily on its first tick, so if rotation:x is already at
	# the target by then, the animation is a no-op zero-length jump).
	_set_opened_material()

func _spawn_gold_burst() -> void:
	if _burst_mat == null:
		_burst_mat = ParticleProcessMaterial.new()
		_burst_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		_burst_mat.emission_sphere_radius = 0.15
		_burst_mat.direction = Vector3(0.0, 1.0, 0.0)
		_burst_mat.spread = 40.0
		_burst_mat.initial_velocity_min = 1.0
		_burst_mat.initial_velocity_max = 2.0
		_burst_mat.gravity = Vector3(0.0, -6.0, 0.0)
		_burst_mat.scale_min = 0.04
		_burst_mat.scale_max = 0.08
		_burst_mat.color = Color(0.9, 0.75, 0.1)
	var burst := GPUParticles3D.new()
	burst.amount = 12
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.emitting = true
	burst.position = Vector3(0.0, 0.45, 0.0)
	burst.process_material = _burst_mat
	add_child(burst)
	get_tree().create_timer(burst.lifetime + 0.2, false).timeout.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free()
	)

func _set_opened_material() -> void:
	if not _opened_mat:
		_opened_mat = StandardMaterial3D.new()
		_opened_mat.albedo_color = Color(0.4, 0.3, 0.0)
	var mi := find_child("MeshInstance3D", true, false)
	if mi is MeshInstance3D:
		mi.material_override = _opened_mat

## Instant "already opened" visual — no tween, no particles. Used by
## `init_from_data()` for save-restored chests. In sprite mode this only
## matters if called after `_sprite` exists — `_ready()` already reads
## `_opened` directly when building the sprite, so the common (pre-`_ready()`)
## call here is a harmless no-op.
func _show_opened() -> void:
	if _sprite != null:
		_sprite.texture = _SpriteRegistry.chest_open_texture()
		return
	_set_opened_material()
	if _lid_hinge != null:
		_lid_hinge.rotation.x = deg_to_rad(_LID_OPEN_ANGLE)
