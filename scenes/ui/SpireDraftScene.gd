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

const SpireDraft = preload("res://game_logic/spire/SpireDraft.gd")

var _floor_number: int = 1
var _draft_logic: RefCounted = null

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
	rng.seed = int(SceneManager.save_manager.get_spire_run().get("seed", 0)) + floor
	var pool_templates: Dictionary = {}
	for id: String in CardRegistry.get_all_ids():
		pool_templates[id] = CardRegistry.get_template(id)
	var picks: Array[String] = _draft_logic.generate_picks(floor, rng, pool_templates)
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

	_UiUtil.make_label("Floor %d — Choose a Card" % _floor_number, int(_ref * 0.038), Color(1.0, 0.88, 0.4), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	# Co-op turn banner: "Your turn!" or "Waiting for <name>…" — every peer sees the
	# same 3 cards, but only the active picker's buttons are interactive.
	if _is_coop:
		_UiUtil.make_label("Your turn!" if _coop_is_my_turn else "Waiting for %s…" % _coop_picker_name, int(_ref * 0.026), Color(0.6, 1.0, 0.6) if _coop_is_my_turn else Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	root_vbox.add_child(HSeparator.new())

	var cards_container := _build_cards_container(root_vbox)
	for card_id: String in picks:
		cards_container.add_child(_make_card_panel(card_id))

	# Spacer so title + cards fill the panel naturally
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(spacer)

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
	SceneManager.save_manager.add_drafted_card(card_id)
	GameBus.spire_card_drafted.emit(card_id)
	picked.emit(card_id)
	queue_free()
