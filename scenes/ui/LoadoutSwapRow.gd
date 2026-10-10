## Swap-deck row (GID-181 / TID-756): one button per saved loadout, the best matchup for the
## enemy's KNOWN weak schools marked with a star, and those weak schools as colour chips.
## Shared by the gambit picker and the world's swap prompt. Picking a loadout makes it the
## active one (SaveLoadouts.set_active_loadout syncs player_deck, which the battle reads at
## setup), rebuilds the row and calls `on_picked(index)` when given.
## Ranking is pure (game_logic/battle/LoadoutMatchup.gd); the card -> school mapping and the
## bestiary gating (SchoolKnowledge.journal_view) happen here.
extends RefCounted

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const _SchoolKnowledge = preload("res://game_logic/battle/SchoolKnowledge.gd")
const _SchoolFeedback = preload("res://game_logic/battle/SchoolFeedback.gd")
const _LoadoutMatchup = preload("res://game_logic/battle/LoadoutMatchup.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _CardRegistry = preload("res://autoloads/CardRegistry.gd")

const _BEST_TINT: Color = Color(1.0, 0.9, 0.45)
const _HINT_TINT: Color = Color(0.75, 0.75, 0.8)

var _enemy_type: String = ""
var _vh: float = 0.0
var _on_picked: Callable = Callable()
var _box: VBoxContainer = null

func _init(enemy_type: String, vh: float, on_picked: Callable = Callable()) -> void:
	_enemy_type = enemy_type
	_vh = vh
	_on_picked = on_picked

## Builds the row into `parent` (any Control or container).
func attach(parent: Node) -> void:
	_box = _UiUtil.make_vbox(int(_vh * 0.01), parent)
	_rebuild()

func _rebuild() -> void:
	if _box == null or not is_instance_valid(_box):
		return
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var save := SceneManager.save_manager
	var entry: Dictionary = save.get_bestiary_entry(_enemy_type)
	var view: Dictionary = _SchoolKnowledge.journal_view("", _EnemyRegistry.get_school_profile(_enemy_type), entry)
	var weak: Array[String] = []
	weak.assign(view.get("weak", []))
	var resist: Array[String] = []
	resist.assign(view.get("resist", []))

	_build_header(weak, bool(view.get("profile_known", false)))

	var entries: Array[Dictionary] = []
	for i: int in range(save.loadouts.size()):
		var lo: Dictionary = save.loadouts[i]
		var cards: Array = lo.get("cards", [])
		var schools: Array[String] = []
		for cid: Variant in cards:
			schools.append(_DamageSchools.school_of(_CardRegistry.get_template(str(cid))))
		entries.append({
			"index": i,
			"name": str(lo.get("name", "Deck")),
			"schools": schools,
			"valid": save.decks.is_loadout_valid(i),
		})
	var ranked: Array[Dictionary] = _LoadoutMatchup.rank(entries, weak, resist)
	var best: int = _LoadoutMatchup.best_index(ranked)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", int(_vh * 0.01))
	flow.add_theme_constant_override("v_separation", int(_vh * 0.01))
	_box.add_child(flow)
	for row: Dictionary in ranked:
		_build_loadout_button(row, best, save.active_loadout, flow)

func _build_header(weak: Array[String], profile_known: bool) -> void:
	var head := _UiUtil.make_hbox(int(_vh * 0.01), _box)
	_UiUtil.make_label("Swap deck", int(_vh * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, head)
	if not profile_known:
		_UiUtil.make_label("Defeat one to learn its weaknesses", int(_vh * 0.018), _HINT_TINT,
				HORIZONTAL_ALIGNMENT_LEFT, head)
		return
	if weak.is_empty():
		_UiUtil.make_label("No weak schools", int(_vh * 0.018), _HINT_TINT, HORIZONTAL_ALIGNMENT_LEFT, head)
		return
	_UiUtil.make_label("Weak to", int(_vh * 0.018), _HINT_TINT, HORIZONTAL_ALIGNMENT_LEFT, head)
	for school: String in weak:
		_build_chip(school, head)

func _build_chip(school: String, parent: Node) -> void:
	var col: Color = _SchoolFeedback.school_color(school)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _UiUtil.make_style(col.darkened(0.6), int(_vh * 0.01), col, 2))
	parent.add_child(chip)
	_UiUtil.make_label(school.capitalize(), int(_vh * 0.018), col, HORIZONTAL_ALIGNMENT_CENTER, chip)

func _build_loadout_button(row: Dictionary, best: int, active: int, parent: Node) -> void:
	var idx: int = int(row.get("index", -1))
	var valid: bool = bool(row.get("valid", false))
	var is_active: bool = idx == active
	var text: String = ("★ " if idx == best else "") + str(row.get("name", "Deck"))
	if not valid:
		text += "  ·  too few cards"
	else:
		text += "  ·  %d weak" % int(row.get("score", 0))
		if is_active:
			text += "  ·  active"
	var btn := _UiUtil.make_button(text, Vector2(_vh * 0.3, _vh * 0.06), int(_vh * 0.02),
			func() -> void: _pick(idx), parent)
	btn.disabled = not valid or is_active
	if idx == best:
		btn.modulate = _BEST_TINT
	btn.tooltip_text = "Best matchup for the enemy's known weak schools" if idx == best else ""

func _pick(index: int) -> void:
	var save := SceneManager.save_manager
	if not save.decks.set_active_loadout(index):
		return
	GameBus.hud_message_requested.emit("Deck swapped: %s" % save.loadouts[index].get("name", "Deck"))
	_rebuild()
	if _on_picked.is_valid():
		_on_picked.call(index)
