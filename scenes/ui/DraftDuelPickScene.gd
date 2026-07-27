## Draft Duel pick overlay (GID-104 / TID-385) — sealed-deck PvP drafting.
##
## Both duelists instantiate this locally with the SAME shared seed; the round
## sequence is fully deterministic (DraftDuelGen.generate_rounds), so no network
## traffic happens per pick. When the final pick is made, `draft_finished(deck)`
## fires with the assembled transient deck (Array of instance dicts) and the
## overlay switches itself into a "Waiting for opponent…" state — the owner
## (WorldScene) frees it when both decks are ready and the battle starts, or on
## abort (peer disconnect / session end).
##
## Drafted cards are TRANSIENT: they exist only in this overlay and the one
## GameState of the resulting duel. They are never written to owned_cards,
## SaveManager, or SessionState.
##
## Mobile/desktop parity: every pick is a Button (touch + mouse); no keybinds.
## The panel, card tiles and tier badges come from DraftPickBase.
extends "res://scenes/ui/DraftPickBase.gd"

signal draft_finished(deck: Array)

const DraftDuelGen = preload("res://game_logic/net/DraftDuelGen.gd")

var _rounds: Array = []            # Array of Array[String] — the shared pick script
var _round_idx: int = 0
var _owner_token: String = ""
var _deck: Array = []              # transient instance dicts picked so far
var _content_root: Control = null  # rebuilt per round

## Call after add_child. Derives the deterministic rounds from the shared seed
## and shows round 1. `owner_token` namespaces the transient instance uids.
func setup(seed_val: int, owner_token: String) -> void:
	_owner_token = owner_token
	var pool_templates: Dictionary = {}
	for id: String in CardRegistry.get_all_ids():
		pool_templates[id] = CardRegistry.get_template(id)
	_rounds = DraftDuelGen.generate_rounds(seed_val, pool_templates)
	if _rounds.is_empty():
		# Headless/no-cards edge: finish immediately with an empty deck; the
		# receiving battle path falls back to its default deck.
		_finish()
		return
	_round_idx = 0
	_build_round_ui()

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _clear_content() -> void:
	if _content_root != null and is_instance_valid(_content_root):
		_content_root.queue_free()
	_content_root = null

func _build_round_ui() -> void:
	_clear_content()
	var panel := _build_draft_panel()
	_content_root = panel["outer"]
	var root_vbox: VBoxContainer = panel["vbox"]

	_UiUtil.make_label("Draft Duel — Pick %d of %d" % [_round_idx + 1, _rounds.size()], int(_ref * 0.038), Color(1.0, 0.88, 0.4), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)

	var subtitle := _UiUtil.make_label("Both players draft from the same sealed pool. Drafted cards last for this duel only.", int(_ref * 0.018), Color(0.75, 0.75, 0.75), HORIZONTAL_ALIGNMENT_CENTER, root_vbox)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	root_vbox.add_child(HSeparator.new())

	var cards_container := _build_cards_container(root_vbox)
	var options: Array = _rounds[_round_idx]
	for cid in options:
		cards_container.add_child(_make_card_panel(str(cid)))

	# Drafted-so-far strip.
	var names: Array[String] = []
	for inst in _deck:
		var d: Dictionary = inst
		var tmpl: Dictionary = CardRegistry.get_template(str(d.get("template_id", "")))
		names.append(str(tmpl.get("name", d.get("template_id", "?"))))
	var drafted := _UiUtil.make_label(
		"Drafted: %s" % (", ".join(names) if not names.is_empty() else "—"),
		int(_ref * 0.018), Color(0.65, 0.85, 0.65), HORIZONTAL_ALIGNMENT_LEFT, root_vbox)
	drafted.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _tier_for(_card_id: String, tmpl: Dictionary) -> int:
	return DraftDuelGen.tier_for_template(tmpl)

# ---------------------------------------------------------------------------
# Pick flow
# ---------------------------------------------------------------------------

func _on_pick(card_id: String) -> void:
	var tmpl: Dictionary = CardRegistry.get_template(card_id)
	var tier: int = DraftDuelGen.tier_for_template(tmpl)
	_deck.append(DraftDuelGen.make_drafted_instance(card_id, tier, _round_idx, _owner_token, tmpl))
	_round_idx += 1
	if _round_idx >= _rounds.size():
		_finish()
	else:
		_build_round_ui()

func _finish() -> void:
	_show_waiting()
	draft_finished.emit(_deck)

## Post-draft holding state: the duel starts once the opponent's deck arrives;
## WorldScene frees this overlay at that point (or on abort).
func _show_waiting() -> void:
	_clear_content()
	var panel := PanelContainer.new()
	var panel_w: float = _vw * 0.6
	var panel_h: float = _vh * 0.2
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(panel)
	_content_root = panel
	var lbl := _UiUtil.make_label("Deck drafted! Waiting for your opponent to finish…", int(_ref * 0.026), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
