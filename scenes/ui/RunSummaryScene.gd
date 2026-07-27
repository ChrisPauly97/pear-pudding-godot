extends Control

const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

# Set before adding to tree to show Spire-specific stats instead of session stats.
var spire_stats: Dictionary = {}

# Set before adding to tree (GID-106 / TID-391) to show the co-op Endless Spire
# run summary instead: {floors_cleared, party_size, roster: Array[String]}. Used
# when this scene is instantiated as a WorldScene child overlay rather than via
# change_scene_to_node — the co-op session stays alive underneath.
var coop_stats: Dictionary = {}

## Emitted only in coop mode when the player presses "Continue" (there is no
## "Return to Menu" for a co-op run — leaving the world entirely isn't the right
## action while the shared session is still live). The caller (WorldScene) does
## the actual shared map transition back to madrian.
signal continue_pressed

var _vh: float = 0.0
var _vw: float = 0.0
var _ref: float = 0.0

func _ready() -> void:
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_ref = minf(_vh, _vw)
	if not coop_stats.is_empty():
		_build_coop_spire_ui()
	elif not spire_stats.is_empty():
		_build_spire_ui()
	else:
		_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.10, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel_w: float = minf(_vw * 0.88, _vh * 0.70)
	var panel_h: float = _vh * 0.85

	var outer := _UiUtil.make_centered_panel(panel_w, panel_h, _vw, _vh, self)

	var margin := _UiUtil.make_margin(int(_vw * 0.025), int(_ref * 0.025), int(_vw * 0.025), int(_ref * 0.025), outer)

	var root_vbox := _UiUtil.make_vbox(int(_ref * 0.018), margin)

	# Title
	var title := _UiUtil.make_label("Session Summary", int(_ref * 0.045), Color(1.0, 0.88, 0.4), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	# Separator
	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Stats grid
	var stats: Dictionary = SceneManager.session_stats
	var elapsed_msec: int = Time.get_ticks_msec() - int(stats.get("session_start_msec", Time.get_ticks_msec()))
	var elapsed_sec: int = elapsed_msec / 1000
	var minutes: int = elapsed_sec / 60
	var seconds: int = elapsed_sec % 60

	var stat_rows: Array = [
		["Battles Won",    str(int(stats.get("battles_won", 0)))],
		["Battles Lost",   str(int(stats.get("battles_lost", 0)))],
		["Enemies Defeated", str(int(stats.get("enemies_defeated", 0)))],
		["Cards Earned",   str(int(stats.get("cards_earned", 0)))],
		["Coins Earned",   str(int(stats.get("coins_earned", 0)))],
		["Chests Opened",  str(int(stats.get("chests_opened", 0)))],
		["Time Played",    "%02d:%02d" % [minutes, seconds]],
	]

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(_vw * 0.04))
	grid.add_theme_constant_override("v_separation", int(_ref * 0.012))
	root_vbox.add_child(grid)

	for row: Array in stat_rows:
		var key_lbl := _UiUtil.make_label(str(row[0]), int(_ref * 0.024), Color(0.75, 0.75, 0.75), HORIZONTAL_ALIGNMENT_LEFT, grid)

		var val_lbl := _UiUtil.make_label(str(row[1]), int(_ref * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, grid)

	# Separator
	var sep2 := HSeparator.new()
	root_vbox.add_child(sep2)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer)

	# Return to menu button
	var btn_wrap := CenterContainer.new()
	root_vbox.add_child(btn_wrap)

	var menu_btn := _UiUtil.make_button("Return to Menu", Vector2(_ref * 0.32, _ref * 0.07), int(_ref * 0.028), _on_menu, btn_wrap)

func _on_menu() -> void:
	SceneManager.go_to_menu_direct()

func _build_spire_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel_w: float = minf(_vw * 0.88, _vh * 0.72)
	var panel_h: float = _vh * 0.88

	var outer := _UiUtil.make_centered_panel(panel_w, panel_h, _vw, _vh, self)

	var margin := _UiUtil.make_margin(int(_vw * 0.025), int(_ref * 0.025), int(_vw * 0.025), int(_ref * 0.025), outer)

	var root_vbox := _UiUtil.make_vbox(int(_ref * 0.016), margin)

	var floors_cleared: int = int(spire_stats.get("floors_cleared", 0))

	# Title
	var title := _UiUtil.make_label("Endless Spire", int(_ref * 0.048), Color(0.75, 0.5, 1.0), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	var subtitle := _UiUtil.make_label("Floor %d" % floors_cleared if floors_cleared > 0 else "Fallen before the first floor", int(_ref * 0.028), Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	# New record badge
	if bool(spire_stats.get("is_new_record", false)) and floors_cleared > 0:
		var record_lbl := _UiUtil.make_label("New Record!", int(_ref * 0.026), Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	root_vbox.add_child(HSeparator.new())

	# Stats grid
	var coins_earned: int = int(spire_stats.get("coins_earned", 0))
	var stat_rows: Array = [
		["Floors Cleared",    str(floors_cleared)],
		["Enemies Defeated",  str(int(spire_stats.get("enemies_defeated", 0)))],
		["Cards Drafted",     str(int(spire_stats.get("cards_drafted", 0)))],
		["Coins Earned",      str(coins_earned)],
		["Best Floor",        str(int(spire_stats.get("best_floor", floors_cleared)))],
	]

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(_vw * 0.04))
	grid.add_theme_constant_override("v_separation", int(_ref * 0.012))
	root_vbox.add_child(grid)

	for row: Array in stat_rows:
		var key_lbl := _UiUtil.make_label(str(row[0]), int(_ref * 0.024), Color(0.75, 0.75, 0.75), HORIZONTAL_ALIGNMENT_LEFT, grid)

		var val_lbl := _UiUtil.make_label(str(row[1]), int(_ref * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, grid)

	# Draft deck list (up to 8 cards)
	var draft_ids: Array = spire_stats.get("draft_deck_ids", [])
	if draft_ids.size() > 0:
		root_vbox.add_child(HSeparator.new())
		var deck_header := _UiUtil.make_label("Cards Drafted", int(_ref * 0.022), Color(0.75, 0.75, 0.75), HORIZONTAL_ALIGNMENT_LEFT, root_vbox)

		var names_vbox := _UiUtil.make_vbox(int(_ref * 0.006), root_vbox)

		var show_count: int = mini(draft_ids.size(), 8)
		for i: int in range(show_count):
			var cid: String = str(draft_ids[i])
			var tmpl: Dictionary = CardRegistry.get_template(cid)
			var card_name: String = str(tmpl.get("name", cid)) if not tmpl.is_empty() else cid
			var card_lbl := _UiUtil.make_label("  • %s" % card_name, int(_ref * 0.020), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, names_vbox)
		if draft_ids.size() > 8:
			var more_lbl := _UiUtil.make_label("  + %d more" % (draft_ids.size() - 8), int(_ref * 0.020), Color(0.65, 0.65, 0.65), HORIZONTAL_ALIGNMENT_LEFT, names_vbox)

	root_vbox.add_child(HSeparator.new())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer)

	var btn_wrap := CenterContainer.new()
	root_vbox.add_child(btn_wrap)

	var menu_btn := _UiUtil.make_button("Return to Menu", Vector2(_ref * 0.32, _ref * 0.07), int(_ref * 0.028), _on_menu, btn_wrap)

## Co-op Endless Spire run summary (GID-106 / TID-391). Shown as a WorldScene
## child overlay (never change_scene_to_node — that would exit the whole co-op
## session). "Continue" replaces "Return to Menu": the shared session stays
## alive and the party heads back to madrian together.
func _build_coop_spire_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel_w: float = minf(_vw * 0.88, _vh * 0.72)
	var panel_h: float = _vh * 0.80

	var outer := _UiUtil.make_centered_panel(panel_w, panel_h, _vw, _vh, self)

	var margin := _UiUtil.make_margin(int(_vw * 0.025), int(_ref * 0.025), int(_vw * 0.025), int(_ref * 0.025), outer)

	var root_vbox := _UiUtil.make_vbox(int(_ref * 0.016), margin)

	var floors_cleared: int = int(coop_stats.get("floors_cleared", 0))

	var title := _UiUtil.make_label("Party Endless Spire", int(_ref * 0.048), Color(0.75, 0.5, 1.0), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	var subtitle := _UiUtil.make_label("Floor %d" % floors_cleared if floors_cleared > 0 else "The party fell before the first floor", int(_ref * 0.028), Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	root_vbox.add_child(HSeparator.new())

	var stat_rows: Array = [
		["Floors Cleared", str(floors_cleared)],
		["Party Size", str(int(coop_stats.get("party_size", 1)))],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(_vw * 0.04))
	grid.add_theme_constant_override("v_separation", int(_ref * 0.012))
	root_vbox.add_child(grid)
	for row: Array in stat_rows:
		var key_lbl := _UiUtil.make_label(str(row[0]), int(_ref * 0.024), Color(0.75, 0.75, 0.75), HORIZONTAL_ALIGNMENT_LEFT, grid)

		var val_lbl := _UiUtil.make_label(str(row[1]), int(_ref * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, grid)

	var roster: Array = coop_stats.get("roster", [])
	if roster.size() > 0:
		root_vbox.add_child(HSeparator.new())
		var roster_header := _UiUtil.make_label("The Party", int(_ref * 0.022), Color(0.75, 0.75, 0.75), HORIZONTAL_ALIGNMENT_LEFT, root_vbox)

		var names_vbox2 := _UiUtil.make_vbox(int(_ref * 0.006), root_vbox)
		for member_name in roster:
			var name_lbl := _UiUtil.make_label("  • %s" % str(member_name), int(_ref * 0.020), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, names_vbox2)

	root_vbox.add_child(HSeparator.new())

	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer2)

	var btn_wrap2 := CenterContainer.new()
	root_vbox.add_child(btn_wrap2)

	var continue_btn := _UiUtil.make_button("Continue", Vector2(_ref * 0.32, _ref * 0.07), int(_ref * 0.028), func() -> void: continue_pressed.emit(), btn_wrap2)
