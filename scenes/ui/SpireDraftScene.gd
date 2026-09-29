## Draft-pick overlay shown after each Spire floor victory.
##
## Usage (single-player):
##   var draft := SpireDraftScene.instantiate()
##   add_child(draft)
##   draft.setup(floor_number)
##   draft.picked.connect(_on_draft_picked)   # receives the chosen card_id
##
## Usage (co-op alternating draft, GID-106 / TID-390):
##   draft.setup_coop(floor_number, broadcast_options, is_my_turn, active_picker_name)
##   if is_my_turn: draft.picked.connect(_submit_coop_spire_draft_choice)
##
## The panel, card tiles and tier badges come from DraftPickBase.
extends "res://scenes/ui/DraftPickBase.gd"

signal picked(card_id: String)

const _RiftDefs = preload("res://game_logic/spire/RiftDefs.gd")
const SpireDraft = preload("res://game_logic/spire/SpireDraft.gd")

var _floor_number: int = 1
var _draft_logic: SpireDraft = null

# Co-op alternating draft (GID-106 / TID-390). _is_coop gates the single-player
# persistence side effects in _on_pick (the co-op grant path is
# SceneManager.add_coop_drafted_card, driven by WorldScene, not
# SaveManager.add_drafted_card / GameBus.spire_card_drafted).
var _is_coop: bool = false
var _coop_is_my_turn: bool = false
var _coop_picker_name: String = ""

## Call after instantiation. Generates the picks and builds the UI.
func setup(floor: int) -> void:
	_floor_number = floor
	_draft_logic = SpireDraft.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(SceneManager.save_manager.spire.get_spire_run().get("seed", 0)) + floor
	var pool_templates: Dictionary = {}
	for id: String in CardRegistry.get_all_ids():
		pool_templates[id] = CardRegistry.get_template(id)
	var picks: Array[String] = _draft_logic.generate_picks(floor, rng, pool_templates)
	# GID-142 / TID-598: a rift run offers two temporary cards and one buff boon.
	if SceneManager.save_manager.spire.uses_own_deck() and picks.size() >= 3:
		var boon_ids: Array = _RiftDefs.BOONS.keys()
		picks[2] = str(boon_ids[rng.randi_range(0, boon_ids.size() - 1)])
	_build_ui(picks)

## Co-op entry point (WorldScene._on_spire_draft_start_received): unlike setup(),
## `options` are pre-broadcast by the authority — never regenerated locally, so
## every peer renders identical cards. `is_my_turn` gates interactivity: only the
## active picker's buttons are enabled; everyone else sees a disabled "waiting" banner.
func setup_coop(floor: int, options: Array[String], is_my_turn: bool, picker_name: String) -> void:
	_floor_number = floor
	_draft_logic = SpireDraft.new()  # still needed for card_tier() lookups in _tier_for
	_is_coop = true
	_coop_is_my_turn = is_my_turn
	_coop_picker_name = picker_name
	_build_ui(options)

func _build_ui(picks: Array[String]) -> void:
	var root_vbox: VBoxContainer = _build_draft_panel()["vbox"]

	var boon_run: bool = not _is_coop and SceneManager.save_manager.spire.uses_own_deck()
	_UiUtil.make_label("Floor %d — Choose a Boon" % _floor_number if boon_run
			else "Floor %d — Choose a Card" % _floor_number, int(_ref * 0.038), Color(1.0, 0.88, 0.4),
			HORIZONTAL_ALIGNMENT_CENTER, root_vbox)
	if boon_run:
		_UiUtil.make_label("Picks last this run only — cards join your deck until the rift ends.",
				int(_ref * 0.02), Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	# Co-op turn banner: "Your turn!" or "Waiting for <name>…" — every peer sees the
	# same 3 cards, but only the active picker's buttons are interactive.
	if _is_coop:
		_UiUtil.make_label("Your turn!" if _coop_is_my_turn else "Waiting for %s…" % _coop_picker_name,
				int(_ref * 0.026), Color(0.6, 1.0, 0.6) if _coop_is_my_turn else Color(0.85, 0.85, 0.85),
				HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	root_vbox.add_child(HSeparator.new())

	var cards_container := _build_cards_container(root_vbox)
	for card_id: String in picks:
		cards_container.add_child(_make_boon_panel(card_id) if _RiftDefs.is_boon(card_id)
				else _make_card_panel(card_id))

	# Spacer so title + cards fill the panel naturally
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer)

## A buff boon's pick panel (name, what it does, Pick) in the card row.
func _make_boon_panel(boon_id: String) -> Control:
	var d: Dictionary = _RiftDefs.BOONS[boon_id]
	var outer := PanelContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := _UiUtil.make_margin(int(_vw * 0.012), int(_ref * 0.012), int(_vw * 0.012), int(_ref * 0.012),
			outer)
	var vbox := _UiUtil.make_vbox(int(_ref * 0.008), margin)
	_UiUtil.make_label(str(d["name"]), int(_ref * 0.026), Color(0.55, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT, vbox)
	_UiUtil.make_label("Boon", int(_ref * 0.02), Color(0.55, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT, vbox)
	var desc := _UiUtil.make_label(str(d["desc"]), int(_ref * 0.02), Color(0.8, 0.8, 0.85),
			HORIZONTAL_ALIGNMENT_LEFT, vbox)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pick := _UiUtil.make_button("Pick", Vector2(0.0, _ref * 0.055), int(_ref * 0.023), _on_pick.bind(boon_id), vbox)
	pick.disabled = _pick_disabled()
	return outer

func _tier_for(card_id: String, _tmpl: Dictionary) -> int:
	return _draft_logic.card_tier(card_id)

func _pick_disabled() -> bool:
	return _is_coop and not _coop_is_my_turn

func _on_pick(card_id: String) -> void:
	if _is_coop:
		# Defensive: the button is already disabled for a non-active picker, but
		# never emit/free on a stray signal. Co-op persistence (SceneManager.
		# add_coop_drafted_card) is driven by WorldScene after the authority
		# resolves the pick — this scene never touches SaveManager/GameBus in co-op.
		if not _coop_is_my_turn:
			return
		picked.emit(card_id)
		queue_free()
		return
	if _RiftDefs.is_boon(card_id):
		SceneManager.save_manager.spire.add_boon(card_id)
	else:
		SceneManager.save_manager.spire.add_drafted_card(card_id)
		GameBus.spire_card_drafted.emit(card_id)
	picked.emit(card_id)
	queue_free()
