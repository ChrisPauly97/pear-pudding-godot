## Shared party stash panel (GID-102 / TID-376).
##
## A session-owned chest any co-op member can deposit cards/coins into and withdraw
## from. Two columns: my collection (deposit) on the left, stash contents (withdraw)
## on the right, plus a coins row with deposit/withdraw stepper buttons.
##
## Script-only overlay (instantiated via .new()), matching LeaderboardOverlay /
## SettingsScene / MultiplayerLobbyScene (extends BaseOverlay by path string,
## viewport-relative, rebuilt on resize). Opened from a "Stash" HUD button in
## WorldScene — a touch/click target, mobile + desktop parity per CLAUDE.md.
##
## Unique cards never appear in the "deposit" list (WorldScene.request_stash_deposit_card
## only fires for cards actually shown here, and the authority double-checks via
## StashTransfer.deposit_card regardless — defense in depth).
extends "res://scenes/ui/BaseOverlay.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _CardRegistry = preload("res://autoloads/CardRegistry.gd")

## Set by WorldScene right after instantiation so button presses can call back.
var world_scene: Node = null

var _my_cards_vbox: VBoxContainer = null
var _stash_cards_vbox: VBoxContainer = null
var _coins_label: Label = null
var _my_cards_cache: Array = []
var _stash_cache: Dictionary = {"cards": [], "coins": 0}

const _COIN_STEP: int = 50


func _ready() -> void:
	super._ready()
	_build_ui()


func _build_ui() -> void:
	_build_backdrop(0.72, true)

	var panel_w: float = _vw * 0.78
	var panel_h: float = _vh * 0.74
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var outer_vbox := _build_margin_vbox(panel, 0.04, 0.02)

	outer_vbox.add_child(_UiUtil.make_title_label("Party Stash", _vh))
	outer_vbox.add_child(_UiUtil.make_separator())

	_build_coins_row(outer_vbox)
	outer_vbox.add_child(_UiUtil.make_separator())

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", int(_ref * 0.025))
	outer_vbox.add_child(columns)

	var my_col := _build_column(columns, "My Collection")
	_my_cards_vbox = my_col

	var stash_col := _build_column(columns, "Stash")
	_stash_cards_vbox = stash_col

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(_UiUtil.make_close_button(_vh, _close))
	outer_vbox.add_child(btn_row)

	_render_lists()


func _build_column(parent: HBoxContainer, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", int(_ref * 0.01))
	parent.add_child(col)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
	title_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	attach_drag_scroll(scroll)

	var rows_vbox := VBoxContainer.new()
	rows_vbox.add_theme_constant_override("separation", int(_ref * 0.01))
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_vbox)
	return rows_vbox


func _build_coins_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(_ref * 0.02))
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = "Stash Coins:"
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.024))
	row.add_child(lbl)

	_coins_label = Label.new()
	_coins_label.text = "0"
	_coins_label.add_theme_font_size_override("font_size", int(_vh * 0.024))
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	row.add_child(_coins_label)

	var deposit_btn := Button.new()
	deposit_btn.text = "Deposit %d" % _COIN_STEP
	deposit_btn.custom_minimum_size = Vector2(_vh * 0.16, _vh * 0.055)
	deposit_btn.add_theme_font_size_override("font_size", int(_vh * 0.020))
	deposit_btn.pressed.connect(func() -> void:
		if world_scene != null and world_scene.has_method("request_stash_deposit_coins"):
			world_scene.request_stash_deposit_coins(_COIN_STEP)
	)
	row.add_child(deposit_btn)

	var withdraw_btn := Button.new()
	withdraw_btn.text = "Withdraw %d" % _COIN_STEP
	withdraw_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.055)
	withdraw_btn.add_theme_font_size_override("font_size", int(_vh * 0.020))
	withdraw_btn.pressed.connect(func() -> void:
		if world_scene != null and world_scene.has_method("request_stash_withdraw_coins"):
			world_scene.request_stash_withdraw_coins(_COIN_STEP)
	)
	row.add_child(withdraw_btn)


## Called by WorldScene whenever the local collection or a fresh stash snapshot changes.
func refresh(my_cards: Array, stash_snapshot: Dictionary) -> void:
	_my_cards_cache = my_cards
	_stash_cache = stash_snapshot
	if is_inside_tree() and _my_cards_vbox != null and is_instance_valid(_my_cards_vbox):
		_render_lists()


func _render_lists() -> void:
	if _coins_label != null:
		_coins_label.text = str(int(_stash_cache.get("coins", 0)))

	if _my_cards_vbox != null:
		for c in _my_cards_vbox.get_children():
			c.queue_free()
		var deposit_any: bool = false
		for inst: Variant in _my_cards_cache:
			if not (inst is Dictionary):
				continue
			var d: Dictionary = inst as Dictionary
			var tmpl: Dictionary = _CardRegistry.get_template(str(d.get("template_id", "")))
			if bool(tmpl.get("is_unique", false)):
				continue  # unique cards never leave the owner — not offered here
			deposit_any = true
			_add_card_row(_my_cards_vbox, d, true)
		if not deposit_any:
			_add_empty_label(_my_cards_vbox, "No tradeable cards.")

	if _stash_cards_vbox != null:
		for c in _stash_cards_vbox.get_children():
			c.queue_free()
		var stash_cards: Array = _stash_cache.get("cards", []) as Array
		if stash_cards.is_empty():
			_add_empty_label(_stash_cards_vbox, "Stash is empty.")
		for inst: Variant in stash_cards:
			if inst is Dictionary:
				_add_card_row(_stash_cards_vbox, inst as Dictionary, false)


func _add_empty_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.020))
	lbl.modulate = Color(0.7, 0.7, 0.7)
	parent.add_child(lbl)


func _add_card_row(parent: VBoxContainer, inst: Dictionary, is_mine: bool) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(_ref * 0.015))
	parent.add_child(hb)

	var name_lbl := Label.new()
	var tmpl_id: String = str(inst.get("template_id", "?"))
	name_lbl.text = "%s (%s)" % [tmpl_id, str(inst.get("rarity", "common"))]
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.020))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(name_lbl)

	var uid: String = str(inst.get("uid", ""))
	var action_btn := Button.new()
	action_btn.text = "Deposit" if is_mine else "Withdraw"
	action_btn.custom_minimum_size = Vector2(_vh * 0.16, _vh * 0.05)
	action_btn.add_theme_font_size_override("font_size", int(_vh * 0.018))
	if is_mine:
		action_btn.pressed.connect(func() -> void:
			if world_scene != null and world_scene.has_method("request_stash_deposit_card"):
				world_scene.request_stash_deposit_card(uid)
		)
	else:
		action_btn.pressed.connect(func() -> void:
			if world_scene != null and world_scene.has_method("request_stash_withdraw_card"):
				world_scene.request_stash_withdraw_card(uid)
		)
	hb.add_child(action_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_vh = get_viewport().get_visible_rect().size.y
		_vw = get_viewport().get_visible_rect().size.x
		_ref = minf(_vh, _vw)
		for c in get_children():
			c.queue_free()
		_build_ui()
