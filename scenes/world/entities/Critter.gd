## One ambient critter (CritterDef species): wanders near its home, pauses,
## flees the hero, hovers (butterflies, bees) or hops (snow rabbits). Pure
## scenery — no collision, health or save state. Spawned by modules/Critters.gd.
extends Node3D

const _CritterDef = preload("res://game_logic/world/CritterDef.gd")
const _SpriteOutline = preload("res://game_logic/SpriteOutline.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

const FLY_HEIGHT: float = 0.9
const HOP_HEIGHT: float = 0.35

var species: String = ""
var _height_fn: Callable      # (x: float, z: float) -> float terrain height
var _walkable_fn: Callable    # (x: float, z: float) -> bool
var _threat_fn: Callable      # () -> Vector3 hero position
var _params: Dictionary = {}
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _pause: float = 0.0
var _t: float = 0.0
var _hop: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sprite: AnimatedSprite3D = null


func setup(key: String, home: Vector3, seed_v: int, height_fn: Callable, walkable_fn: Callable,
		threat_fn: Callable) -> void:
	species = key
	_params = _CritterDef.params(key)
	_home = home
	_target = home
	_height_fn = height_fn
	_walkable_fn = walkable_fn
	_threat_fn = threat_fn
	_rng.seed = seed_v
	_t = _rng.randf() * 10.0
	_pause = _rng.randf_range(0.0, 1.5)
	position = home


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"move")
	frames.set_animation_speed(&"move", 10.0 if bool(_params.get("fly", false)) else 7.0)
	var h_px: int = 1
	for tex: Variant in _CritterDef.FRAMES.get(species, []) as Array:
		var t2 := tex as Texture2D
		frames.add_frame(&"move", t2)
		h_px = maxi(h_px, t2.get_height())
	_sprite = AnimatedSprite3D.new()
	_sprite.sprite_frames = frames
	_sprite.animation = &"move"
	var px: float = _SpriteRegistry.CHAR_PIXEL_SIZE * float(_params.get("scale", 1.0))
	_sprite.pixel_size = px
	_SpriteRegistry.apply_billboard_flags(_sprite)
	_sprite.shaded = false
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sprite.position.y = float(h_px) * px * 0.5 + 0.02
	if species == "butterfly":
		_sprite.modulate = _CritterDef.WING_TINTS[_rng.randi() % _CritterDef.WING_TINTS.size()]
	elif _params.has("glow"):
		_sprite.modulate = _params["glow"]  # will-o'-wisps (GID-174)
	add_child(_sprite)
	_SpriteOutline.apply(_sprite)
	if bool(_params.get("fly", false)):
		_sprite.play(&"move")


func _process(delta: float) -> void:
	_t += delta
	var flies: bool = bool(_params.get("fly", false))
	var speed: float = float(_params.get("speed", 1.0))
	if not flies and _threat_fn.is_valid():
		var threat: Vector3 = _threat_fn.call()
		var dx: float = threat.x - position.x
		var dz: float = threat.z - position.z
		if dx * dx + dz * dz < _CritterDef.FLEE_DIST * _CritterDef.FLEE_DIST and _pause >= 0.0:
			var away: Vector3 = _CritterDef.flee_target(position, threat)
			if _can_stand(away):
				_target = away
				_pause = -1.0  # fleeing: no pause until it arrives
	var to := Vector3(_target.x - position.x, 0.0, _target.z - position.z)
	var dist: float = to.length()
	if dist < 0.05:
		if _pause < 0.0:
			_home = position  # settle where it fled to
			_pause = 0.0
		if not flies:
			_sprite.stop()
			_sprite.frame = 0
		_pause -= delta if _pause > 0.0 else 0.0
		if _pause <= 0.0:
			var pause_rng: Vector2 = _params.get("pause", Vector2(1.0, 2.0))
			_pause = _rng.randf_range(pause_rng.x, pause_rng.y)
			var nt: Vector3 = _CritterDef.wander_target(_home, species, _rng)
			if _can_stand(nt):
				_target = nt
		_hop = 0.0
	else:
		var run: float = speed * (2.0 if _pause < 0.0 else 1.0)
		var step: Vector3 = to / dist * minf(dist, run * delta)
		position.x += step.x
		position.z += step.z
		_sprite.flip_h = _CritterDef.faces_left(step)
		if not flies and not _sprite.is_playing():
			_sprite.play(&"move")
		_hop = fposmod(_hop + delta * 3.0, 1.0)
	var y: float = float(_height_fn.call(position.x, position.z)) if _height_fn.is_valid() else position.y
	if flies:
		y += FLY_HEIGHT + sin(_t * 2.3) * 0.18 + sin(_t * 7.1) * 0.05
	elif bool(_params.get("hop", false)) and dist >= 0.05:
		y += sin(_hop * PI) * HOP_HEIGHT
	position.y = y


func _can_stand(p: Vector3) -> bool:
	if bool(_params.get("fly", false)) or not _walkable_fn.is_valid():
		return true
	return bool(_walkable_fn.call(p.x, p.z))
