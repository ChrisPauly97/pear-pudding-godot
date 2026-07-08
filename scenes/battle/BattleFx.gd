extends RefCounted

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const ZoneState = preload("res://game_logic/battle/ZoneState.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")

var _state: GameState
var _vh: float
var _float_layer: CanvasLayer
var _enemy_hero_view: Control
var _player_hero_view: Control
var _enemy_board_view: Control
var _player_board_view: Control
var _scene_root: Control
var _intent_panel: Control = null
var _is_shaking: bool = false

func setup(
	p_vh: float,
	p_float_layer: CanvasLayer,
	p_enemy_hero: Control,
	p_player_hero: Control,
	p_enemy_board: Control,
	p_player_board: Control,
	p_root: Control
) -> void:
	_vh = p_vh
	_float_layer = p_float_layer
	_enemy_hero_view = p_enemy_hero
	_player_hero_view = p_player_hero
	_enemy_board_view = p_enemy_board
	_player_board_view = p_player_board
	_scene_root = p_root

func set_game_state(state: GameState) -> void:
	_state = state

# -------------------------------------------------------------------------
# Intent banner
# -------------------------------------------------------------------------

func show_intent_banner(text: String) -> void:
	hide_intent_banner()
	var vp: Vector2 = _scene_root.get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.18, 0.88)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	_scene_root.add_child(panel)
	panel.reset_size()
	var sz: Vector2 = panel.get_minimum_size()
	panel.position = Vector2((vp.x - sz.x) * 0.5, vp.y * 0.35)
	_scene_root.move_child(panel, _scene_root.get_child_count() - 1)
	_intent_panel = panel

func hide_intent_banner() -> void:
	if _intent_panel != null and is_instance_valid(_intent_panel):
		_intent_panel.queue_free()
	_intent_panel = null

# -------------------------------------------------------------------------
# Status effect turn processing
# -------------------------------------------------------------------------

func process_start_of_turn_statuses(player_idx: int) -> void:
	var player: PlayerState = _state.players[player_idx]
	for card: CardInstance in player.board.get_cards():
		_tick_statuses_on_card(card)
	_tick_statuses_on_hero(player.hero, player_idx)

func _tick_statuses_on_card(card: CardInstance) -> void:
	if card.has_status("poison"):
		var dmg: int = card.get_status_value("poison")
		card.take_damage(dmg)
		var nv: int = dmg - 1
		if nv <= 0:
			card.clear_status("poison")
		else:
			card.apply_status("poison", nv)
		GameBus.status_ticked.emit(card.instance_id, "poison", maxi(nv, 0))
	if card.has_status("freeze"):
		var dur: int = card.get_status_value("freeze") - 1
		if dur <= 0:
			card.clear_status("freeze")
		else:
			card.apply_status("freeze", dur)
		GameBus.status_ticked.emit(card.instance_id, "freeze", maxi(dur, 0))

func _tick_statuses_on_hero(hero: HeroState, player_idx: int) -> void:
	var hid: String = "hero_%d" % player_idx
	if hero.has_status("poison"):
		var dmg: int = hero.get_status_value("poison")
		hero.take_damage(dmg)
		var nv: int = dmg - 1
		if nv <= 0:
			hero.clear_status("poison")
		else:
			hero.apply_status("poison", nv)
		GameBus.status_ticked.emit(hid, "poison", maxi(nv, 0))

# -------------------------------------------------------------------------
# Status icon rendering — unified
# -------------------------------------------------------------------------

func update_status_icons_card(hbox: HBoxContainer, card: CardInstance) -> void:
	_update_status_icons_impl(hbox, card)

func update_status_icons_hero(hbox: HBoxContainer, hero: HeroState) -> void:
	_update_status_icons_impl(hbox, hero)

func _update_status_icons_impl(hbox: HBoxContainer, entity) -> void:
	for child in hbox.get_children():
		child.queue_free()
	var effects: Array[String] = ["poison", "armor", "freeze", "stun"]
	var colors: Array[Color] = [Color.GREEN, Color.CORNFLOWER_BLUE, Color.CYAN, Color.YELLOW]
	var abbrevs: Array[String] = ["P", "A", "F", "S"]
	var icon_sz: float = _vh * 0.022
	for i in range(effects.size()):
		if not entity.has_status(effects[i]):
			continue
		var lbl := Label.new()
		lbl.text = "%s%d" % [abbrevs[i], entity.get_status_value(effects[i])]
		lbl.add_theme_color_override("font_color", colors[i])
		lbl.add_theme_font_size_override("font_size", int(icon_sz))
		hbox.add_child(lbl)

# -------------------------------------------------------------------------
# Snapshot + floating numbers
# -------------------------------------------------------------------------

func pos_of_hero(is_enemy: bool) -> Vector2:
	var hv: Control = _enemy_hero_view if is_enemy else _player_hero_view
	return hv.get_global_rect().get_center()

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(2):
		var hero: HeroState = _state.players[i].hero
		result.append({"id": "hero_%d" % i, "hp": hero.health, "pos": pos_of_hero(i == 1)})
		var zv: Node = _enemy_board_view if i == 1 else _player_board_view
		var zone_name: String = "enemy_board" if i == 1 else "board"
		var fallback: Vector2 = _scene_root.get_viewport().get_visible_rect().size * 0.5
		for si in range(ZoneState.SLOT_COUNT):
			var card: CardInstance = _state.players[i].board.slots[si]
			if card == null:
				continue
			var panel_pos: Vector2 = fallback
			for child in zv.get_children():
				if child is Control and int(child.get_meta("slot_idx", -1)) == si:
					panel_pos = (child as Control).get_global_rect().get_center()
					break
			result.append({
				"id": card.instance_id, "hp": card.health, "pos": panel_pos,
				"zone": zone_name, "slot_idx": si,
			})
	return result

## Locates the still-live board panel a snapshot entry referred to, by zone +
## slot_idx recorded at snapshot time. Works even after the underlying
## CardInstance has been removed from ZoneState.slots (e.g. it died), as long
## as `_refresh_all()` hasn't rebuilt the zone yet — the panel/meta survive.
func find_panel_by_snapshot_entry(entry: Dictionary) -> Control:
	if not entry.has("zone") or not entry.has("slot_idx"):
		return null
	var zv: Node = _enemy_board_view if entry["zone"] == "enemy_board" else _player_board_view
	var target_slot: int = int(entry["slot_idx"])
	for child in zv.get_children():
		if child is Control and int(child.get_meta("slot_idx", -1)) == target_slot:
			return child as Control
	return null

## Pure: given a pre-mutation snapshot and the set of card instance ids still
## alive post-mutation, returns the ids of non-hero entries that died.
static func detect_deaths(snap: Array[Dictionary], alive_ids: Array[String]) -> Array[String]:
	var alive_set: Dictionary = {}
	for id: String in alive_ids:
		alive_set[id] = true
	var dead: Array[String] = []
	for entry: Dictionary in snap:
		var eid: String = str(entry["id"])
		if eid.begins_with("hero_"):
			continue
		if not alive_set.has(eid):
			dead.append(eid)
	return dead

## Pure: scales a base animation duration by the battle-speed setting.
static func scaled_duration(base: float, speed_scale: float) -> float:
	return maxf(0.01, base * speed_scale)

func spawn_float_labels(snap: Array[Dictionary]) -> void:
	var cur_hp: Dictionary = {}
	for i in range(2):
		cur_hp["hero_%d" % i] = _state.players[i].hero.health
		for c: CardInstance in _state.players[i].board.get_cards():
			cur_hp[c.instance_id] = c.health
	for entry: Dictionary in snap:
		var eid: String = str(entry["id"])
		var hp_before: int = int(entry["hp"])
		var pos: Vector2 = entry["pos"] as Vector2
		var hp_after: int = 0
		if cur_hp.has(eid):
			hp_after = int(cur_hp[eid])
		var diff: int = hp_after - hp_before
		if diff < 0:
			spawn_float_label(pos, str(diff), Color(1.0, 0.267, 0.267))
		elif diff > 0:
			spawn_float_label(pos, "+%d" % diff, Color(0.267, 1.0, 0.533))

func spawn_float_label(pos: Vector2, text: String, color: Color) -> void:
	if _float_layer == null or not is_instance_valid(_float_layer):
		return
	var font_sz: int = int(_vh * 0.035) if _vh > 0.0 else 18
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = pos - Vector2(15.0, 10.0)
	_float_layer.add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 70.0, 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(lbl.queue_free)

# -------------------------------------------------------------------------
# Card panel helper
# -------------------------------------------------------------------------

func get_card_panel(card: CardInstance, is_enemy: bool) -> Control:
	var player: PlayerState = _state.players[1] if is_enemy else _state.players[0]
	var zv: Node = _enemy_board_view if is_enemy else _player_board_view
	var slot_idx: int = player.board.slots.find(card)
	if slot_idx == -1:
		return null
	for child in zv.get_children():
		if child is Control and int(child.get_meta("slot_idx", -1)) == slot_idx:
			return child as Control
	return null

# -------------------------------------------------------------------------
# Hit flash
# -------------------------------------------------------------------------

func flash_node(node: Control, flash_color: Color) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "modulate", flash_color, 0.0)
	tw.tween_property(node, "modulate", Color.WHITE, 0.25)

func flash_from_snapshot(snap: Array[Dictionary]) -> void:
	var cur_hp: Dictionary = {}
	for i in range(2):
		cur_hp["hero_%d" % i] = _state.players[i].hero.health
		for c: CardInstance in _state.players[i].board.get_cards():
			cur_hp[c.instance_id] = c.health
	for entry: Dictionary in snap:
		var eid: String = str(entry["id"])
		var hp_before: int = int(entry["hp"])
		if not cur_hp.has(eid):
			continue
		var hp_after: int = int(cur_hp[eid])
		if hp_after == hp_before:
			continue
		var fcolor: Color = Color(1.0, 0.3, 0.3, 1.0) if hp_after < hp_before else Color(0.3, 1.0, 0.5, 1.0)
		if eid.begins_with("hero_"):
			var hv: Control = _enemy_hero_view if eid == "hero_1" else _player_hero_view
			flash_node(hv, fcolor)
		else:
			var found_panel: bool = false
			for pi in range(2):
				if found_panel:
					break
				var zv: Node = _enemy_board_view if pi == 1 else _player_board_view
				for si in range(ZoneState.SLOT_COUNT):
					var card: CardInstance = _state.players[pi].board.slots[si]
					if card != null and card.instance_id == eid:
						for child in zv.get_children():
							if child is Control and int(child.get_meta("slot_idx", -1)) == si:
								flash_node(child as Control, fcolor)
								break
						found_panel = true
						break

# -------------------------------------------------------------------------
# Impact motion — attacker lunge, hit-stop, death (TID-426)
# -------------------------------------------------------------------------

## Lunges `attacker_panel` ~60% of the way toward `target_pos` and back, with
## an optional hit-stop pause at the apex for big/lethal hits. All durations
## are scaled by `speed_scale` (battle fast-mode). Safe if the panel is freed
## mid-tween (board rebuild, battle end).
func animate_attack(attacker_panel: Control, target_pos: Vector2, speed_scale: float = 1.0, hit_stop: float = 0.0) -> void:
	if attacker_panel == null or not is_instance_valid(attacker_panel):
		return
	var origin: Vector2 = attacker_panel.global_position
	var center: Vector2 = attacker_panel.get_global_rect().get_center()
	var lunge_pos: Vector2 = origin + (target_pos - center) * 0.6
	var prev_z: int = attacker_panel.z_index
	attacker_panel.z_index = 10
	var tw_in: Tween = attacker_panel.create_tween()
	tw_in.tween_property(attacker_panel, "global_position", lunge_pos, scaled_duration(0.12, speed_scale)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw_in.finished
	if not is_instance_valid(attacker_panel):
		return
	if hit_stop > 0.0:
		await get_tree().create_timer(scaled_duration(hit_stop, speed_scale), false).timeout
	if not is_instance_valid(attacker_panel):
		return
	var tw_out: Tween = attacker_panel.create_tween()
	tw_out.tween_property(attacker_panel, "global_position", origin, scaled_duration(0.15, speed_scale)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_out.finished
	if is_instance_valid(attacker_panel):
		attacker_panel.z_index = prev_z

## Shrinks/fades/rotates a ghost copy of `panel` in `_float_layer` so a death
## reads as a beat instead of a pop when `_refresh_all()` removes it. Not a
## coroutine — starts the tween immediately and returns it so callers can fire
## several deaths in parallel and await each returned Tween's `finished`.
func animate_death(panel: Control, speed_scale: float = 1.0) -> Tween:
	if panel == null or not is_instance_valid(panel):
		return null
	if _float_layer == null or not is_instance_valid(_float_layer):
		return null
	var ghost: Control = panel.duplicate() as Control
	if ghost == null:
		return null
	ghost.position = panel.get_global_rect().position
	ghost.size = panel.size
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(ghost)
	ghost.pivot_offset = ghost.size * 0.5
	var tw: Tween = ghost.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "scale", Vector2(0.1, 0.1), scaled_duration(0.25, speed_scale))
	tw.tween_property(ghost, "modulate:a", 0.0, scaled_duration(0.25, speed_scale))
	tw.tween_property(ghost, "rotation", deg_to_rad(25.0), scaled_duration(0.25, speed_scale))
	tw.finished.connect(func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free())
	return tw

func get_tree() -> SceneTree:
	return _scene_root.get_tree()

# -------------------------------------------------------------------------
# Haptic + screen shake
# -------------------------------------------------------------------------

func haptic(duration_ms: int) -> void:
	if not OS.has_feature("mobile"):
		return
	if bool(SceneManager.save_manager.get_setting("haptics", true)):
		Input.vibrate_handheld(duration_ms)

func trigger_shake(magnitude: float, duration: float) -> void:
	if not bool(SceneManager.save_manager.get_setting("screen_shake", true)):
		return
	if _is_shaking:
		return
	_is_shaking = true
	var origin: Vector2 = _scene_root.position
	var tw: Tween = _scene_root.create_tween()
	var steps: int = maxi(2, int(duration / 0.05))
	for _i in range(steps):
		var ox: float = randf_range(-magnitude, magnitude)
		var oy: float = randf_range(-magnitude, magnitude)
		tw.tween_property(_scene_root, "position", origin + Vector2(ox, oy), 0.05)
	tw.tween_property(_scene_root, "position", origin, 0.05)
	tw.tween_callback(func() -> void: _is_shaking = false)

func check_shake(snap: Array[Dictionary]) -> void:
	var cur_hp: Dictionary = {}
	for i in range(2):
		cur_hp["hero_%d" % i] = _state.players[i].hero.health
		for c: CardInstance in _state.players[i].board.get_cards():
			cur_hp[c.instance_id] = c.health
	var hero_died: bool = false
	var max_dmg: int = 0
	for entry: Dictionary in snap:
		var eid: String = str(entry["id"])
		var hp_before: int = int(entry["hp"])
		var hp_after: int = 0
		if cur_hp.has(eid):
			hp_after = int(cur_hp[eid])
		var dmg: int = hp_before - hp_after
		if dmg > max_dmg:
			max_dmg = dmg
		if eid.begins_with("hero_") and hp_before > 0 and hp_after == 0:
			hero_died = true
	if hero_died:
		trigger_shake(10.0, 0.35)
	elif max_dmg >= 5:
		trigger_shake(5.0, 0.2)

# -------------------------------------------------------------------------
# Convenience: float labels + flash + shake in one call
# -------------------------------------------------------------------------

func trigger_fx(snap: Array[Dictionary]) -> void:
	spawn_float_labels(snap)
	flash_from_snapshot(snap)
	check_shake(snap)
