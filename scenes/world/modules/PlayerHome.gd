## Player home (docs/agent/player-home.md): the "House For Sale" door panel,
## the bed respawn point, and the trophy pedestals inside. The garden plots are
## HomeGarden's. `make_trophy_pedestal` is shared with the co-op guildhall.
extends Node

const TrophyRegistry = preload("res://game_logic/TrophyRegistry.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const HOUSE_PRICE: int = 500
const BED_TILE := Vector2i(50, 53)
## Pedestal order and tiles inside the home interior.
const TROPHY_IDS: Array[String] = ["champion", "spire_7", "first_boss"]
const TROPHY_TILES: Array[Vector2i] = [Vector2i(44, 49), Vector2i(47, 49), Vector2i(50, 49)]
const _PANEL_BG := Color(0.06, 0.04, 0.14, 0.96)

var _world: Node = null

## The house door: walks straight in once owned, otherwise offers the purchase.
func show_house_door_panel() -> void:
	var sm: Node = SceneManager.save_manager
	if sm.home_owned:
		_enter_home()
		return
	var modal: Dictionary = _world._build_modal(0.60, 0.32, _PANEL_BG, 0.015, 0.02)
	var layer: CanvasLayer = modal["layer"]
	var vbox: VBoxContainer = modal["vbox"]
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var body_font: int = int(vh * 0.027)
	_UiUtil.make_label("House For Sale", int(vh * 0.035), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	var desc_text: String = "Purchase this cozy home for %d coins.\nCurrent balance: %d coins." % [HOUSE_PRICE, sm.coins]
	var desc := _UiUtil.make_label(desc_text, body_font, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hbox := _UiUtil.make_hbox(int(vh * 0.02), vbox)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var buy := func() -> void:
		sm.add_coins(-HOUSE_PRICE)
		sm.home_owned = true
		sm.mark_dirty()
		layer.queue_free()
		_enter_home()
	var buy_btn := _UiUtil.make_button("Buy (%d coins)" % HOUSE_PRICE, Vector2(vh * 0.26, vh * 0.065),
		body_font, buy, hbox)
	buy_btn.disabled = sm.coins < HOUSE_PRICE
	_UiUtil.make_button("Cancel", Vector2(vh * 0.16, vh * 0.065), body_font, layer.queue_free, hbox)

func _enter_home() -> void:
	AudioManager.play_sfx("door_enter")
	SceneManager.enter_map("player_home", "exit_door")

## Resting sets the respawn point to the bed and skips to morning.
func use_bed() -> void:
	var sm: Node = SceneManager.save_manager
	var ts: float = IsoConst.TILE_SIZE
	sm.set_respawn_point("player_home", float(BED_TILE.x) * ts, float(BED_TILE.y) * ts)
	sm.time_of_day = 0.25
	_world._show_dialogue("You rest peacefully at home. Respawn point set!")

## One pedestal per trophy, gold when earned; registered as `trophy_pedestal` NPCs.
func spawn_trophies() -> void:
	var sm: Node = SceneManager.save_manager
	for i: int in range(TROPHY_IDS.size()):
		var tid: String = TROPHY_IDS[i]
		var trophy: Dictionary = TrophyRegistry.get_trophy(tid)
		if trophy.is_empty():
			continue
		var earned: bool = TrophyRegistry.is_earned(tid, sm)
		var display_name: String = str(trophy.get("display_name", tid))
		var wx: float = float(TROPHY_TILES[i].x) * IsoConst.TILE_SIZE
		var wz: float = float(TROPHY_TILES[i].y) * IsoConst.TILE_SIZE
		var dialogue: String = display_name + (": " + str(trophy.get("description", "")) if earned else " (not yet earned)")
		var pedestal: Node3D = make_trophy_pedestal(earned, display_name)
		pedestal.position = Vector3(wx, _world.get_terrain_height(wx, wz), wz)
		_world._entity_root.add_child(pedestal)
		_world.register_npc("trophy_" + tid, pedestal, {
			"id": "trophy_" + tid,
			"x": wx,
			"z": wz,
			"npc_type": "trophy_pedestal",
			"trophy_id": tid,
			"trophy_earned": earned,
			"dialogue": dialogue,
			"flag_key": "",
		})

## Two stacked boxes with a name tag: gold when earned, grey "???" when not.
static func make_trophy_pedestal(earned: bool, display_name: String) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 0.65, 0.2) if earned else Color(0.4, 0.4, 0.4)
	root.add_child(make_box(Vector3(0.9, 0.5, 0.9), 0.25, mat))
	root.add_child(make_box(Vector3(0.5, 0.5, 0.5), 0.75, mat))
	root.add_child(_SpriteRegistry.make_name_label(display_name if earned else "???",
		Color(1.0, 0.9, 0.3) if earned else Color(0.5, 0.5, 0.5), 1.4, 28, 0.022))
	return root

## An unshaded box of `size` whose centre sits `y` above the node origin.
static func make_box(size: Vector3, y: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(0.0, y, 0.0)
	return mi
