## World cantrips (GID-065): deck-family abilities usable outside battle.
##   Ghost Phase  — slip through a single wall tile (4+ Ghost-family cards).
##   Skeleton Dig — dig up a nearby burial mound (Skeleton family).
## Availability and cooldowns are pure logic in CantripManager; this module owns
## the in-world effect. Reached from WorldHUD's buttons and WorldScene's G/D keys.
extends Node

const CantripManager = preload("res://game_logic/world/CantripManager.gd")

const _PHASE_DURATION: float = 0.3
const _PHASE_ALPHA: float = 0.5
const _CARDINALS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _world: Node = null

var _phase_active: bool = false    # true while the phase tween runs
var _phase_tween: Tween = null

func activate_ghost_phase() -> void:
	if _world._player == null or _phase_active:
		return
	var sm: Node = SceneManager.save_manager
	if not CantripManager.is_available("ghost_phase", sm.get_deck_template_ids()):
		GameBus.hud_message_requested.emit("Ghost Phase requires 4+ Ghost-family cards in your deck.")
		return
	var now: float = Time.get_unix_time_from_system()
	if CantripManager.is_on_cooldown("ghost_phase", sm.cantrip_cooldowns, now):
		var remaining: int = CantripManager.cooldown_remaining("ghost_phase", sm.cantrip_cooldowns, now)
		GameBus.hud_message_requested.emit("Ghost Phase on cooldown (%ds)." % remaining)
		return
	var target: Variant = _phase_target()
	if target == null:
		GameBus.hud_message_requested.emit("No wall to phase through in this direction.")
		return
	_start_phase(target as Vector3)
	sm.cantrip_cooldowns["ghost_phase"] = now + CantripManager.get_cooldown("ghost_phase")
	sm.mark_dirty()
	GameBus.cantrip_used.emit("ghost_phase")

## Digs the burial mound in reach. `quiet` suppresses the "nothing here" toast —
## the keyboard shortcut shares D with move_right, so a miss there is normal.
func activate_skeleton_dig(quiet: bool = false) -> void:
	var player: Node3D = _world._player
	if player == null:
		return
	var mound: Node3D = _world._find_nearby_burial_mound(player.position.x, player.position.z, IsoConst.INTERACT_RANGE)
	if mound == null:
		if not quiet:
			GameBus.hud_message_requested.emit("No burial mound nearby to dig.")
		return
	if mound.has_method("interact"):
		mound.interact()

## Where a phase would land: two tiles away through a single wall tile, trying
## the facing direction first and then every cardinal. Null when none qualifies.
func _phase_target() -> Variant:
	var pos: Vector3 = _world._player.position
	var tile_size: float = IsoConst.TILE_SIZE
	var wtx: int = int(floor(pos.x / tile_size))
	var wtz: int = int(floor(pos.z / tile_size))
	for d: Vector2i in _phase_directions():
		if _world.get_tile_global(wtx + d.x, wtz + d.y) != IsoConst.TILE_WALL:
			continue
		var beyond := Vector2i(wtx + d.x * 2, wtz + d.y * 2)
		if _world.get_tile_global(beyond.x, beyond.y) == IsoConst.TILE_WALL:
			continue  # two walls — too thick to phase through
		var tx: float = (float(beyond.x) + 0.5) * tile_size
		var tz: float = (float(beyond.y) + 0.5) * tile_size
		return Vector3(tx, _world.get_terrain_height(tx, tz) + 0.5, tz)
	return null

## Cardinal directions, the one the player last moved in first.
func _phase_directions() -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	var csm: Node = _world._csm
	var move: Vector2 = csm.get_last_move_dir() if csm != null else Vector2.ZERO
	if move.length_squared() > 0.01:
		if absf(move.x) >= absf(move.y):
			dirs.append(Vector2i(1 if move.x > 0 else -1, 0))
		else:
			dirs.append(Vector2i(0, 1 if move.y > 0 else -1))
	for d: Vector2i in _CARDINALS:
		if not dirs.has(d):
			dirs.append(d)
	return dirs

func _start_phase(target: Vector3) -> void:
	var player: CharacterBody3D = _world._player
	_phase_active = true
	player.collision_layer = 0
	player.collision_mask = 0
	_world._set_player_alpha(_PHASE_ALPHA)
	if _phase_tween != null and _phase_tween.is_valid():
		_phase_tween.kill()
	_phase_tween = _world.create_tween()
	_phase_tween.tween_property(player, "position", target, _PHASE_DURATION)
	_phase_tween.tween_callback(_on_phase_done)

func _on_phase_done() -> void:
	var player: CharacterBody3D = _world._player
	if player != null:
		player.collision_layer = 1
		player.collision_mask = 2 | 4
	_world._set_player_alpha(1.0)
	_phase_active = false
