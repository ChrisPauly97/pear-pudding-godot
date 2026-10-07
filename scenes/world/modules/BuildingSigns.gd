## Shop signs outside every building in the stitched towns (GID-168 / TID-689):
## a signpost beside each doorway (`TownSigns`), whose name pops up above it
## while the player is within POPUP_RANGE. Scenery only (no collision, not synced).
## Created by `WorldScene._ensure_world_modules()` as `building_signs`; ticked from
## WorldScene's overworld branch.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _TownSigns = preload("res://game_logic/world/TownSigns.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _SIGN_TEX := preload("res://assets/textures/props/town_sign.png")

const SIGN_HEIGHT: float = 2.2
## World units: the name shows while the player is this close to the sign.
const POPUP_RANGE: float = 6.0
const CHECK_INTERVAL: float = 0.2
const FADE_S: float = 0.25
const LABEL_TINT := Color(1.0, 0.93, 0.75)

var _world: _WorldScene = null
var _root: Node3D = null
var _timer: float = 0.0
## [{"pos": Vector3, "label": Label3D, "shown": bool}]
var _signs: Array[Dictionary] = []


func tick(delta: float) -> void:
	if _root == null:
		if _world.map_name == "main" and not NetworkManager.is_dedicated_server():
			_build()
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	var player: Node3D = _world._player
	if player == null:
		return
	for s: Dictionary in _signs:
		var near: bool = (s["pos"] as Vector3).distance_to(player.position) <= POPUP_RANGE
		if near != bool(s["shown"]):
			s["shown"] = near
			_fade(s["label"] as Label3D, near)


func _build() -> void:
	_root = Node3D.new()
	_root.name = "BuildingSigns"
	_world._entity_root.add_child(_root)
	for town: String in _RealmLayout.town_names():
		for entry: Dictionary in _TownSigns.signs(town):
			var t: Vector2i = _RealmLayout.to_world_tile(town, entry["tile"] as Vector2i)
			var x: float = IsoConst.tile_center(t.x)
			var z: float = IsoConst.tile_center(t.y)
			var holder := Node3D.new()
			holder.position = Vector3(x, _world.get_terrain_height(x, z), z)
			var sprite := Sprite3D.new()
			_SpriteRegistry.apply_billboard_flags(sprite)
			_SpriteRegistry.setup_sprite_height(sprite, _SIGN_TEX, SIGN_HEIGHT)
			holder.add_child(sprite)
			var label: Label3D = _SpriteRegistry.make_name_label(str(entry["name"]), LABEL_TINT,
				SIGN_HEIGHT + 0.6, 40, 0.022)
			label.outline_size = 10
			label.outline_modulate = Color(0.1, 0.07, 0.05, 1.0)
			label.modulate.a = 0.0
			label.visible = false
			holder.add_child(label)
			_root.add_child(holder)
			_signs.append({"pos": holder.position, "label": label, "shown": false})


func _fade(label: Label3D, on: bool) -> void:
	if on:
		label.visible = true
	var tw: Tween = label.create_tween()
	tw.tween_property(label, "modulate:a", 1.0 if on else 0.0, FADE_S)
	if not on:
		tw.tween_callback(label.hide)


## Number of signs placed (tests / debugging).
func sign_count() -> int:
	return _signs.size()
