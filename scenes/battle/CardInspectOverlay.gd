extends "res://scenes/ui/BaseOverlay.gd"

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const SpellEffectLabels = preload("res://game_logic/battle/SpellEffectLabels.gd")

var _card: CardInstance = null
# Multiplier from the "text_scale" accessibility setting (GID-119 / TID-451).
var _ts: float = 1.0

func _ready() -> void:
	super._ready()

func _font(pct: float) -> int:
	return int(_vh * pct * _ts)

## Puts this overlay on screen over `host` and shows `card`.
##
## The move_child is what makes this the topmost child: hosts add the overlay
## while their own content already exists, and without it the overlay draws
## underneath. `on_closed` fires when the player dismisses it — hosts use it to
## drop their reference so the next inspect request is allowed through.
func present(host: Node, card: CardInstance, on_closed: Callable) -> void:
	host.add_child(self)
	host.move_child(self, host.get_child_count() - 1)
	show_card(card)
	closed.connect(on_closed)

func show_card(card: CardInstance) -> void:
	_card = card
	_ts = clampf(float(SceneManager.save_manager.get_setting("text_scale", 1.0)), 0.5, 2.0)
	_build_ui()

func _build_ui() -> void:
	_build_backdrop(0.72, true)

	var is_dual: bool = _card != null and _card.dual_card_id != ""

	if is_dual:
		_build_dual_face_ui()
	else:
		_build_single_face_ui()

# Single-face layout (existing cards and non-dual side of display)
func _build_single_face_ui() -> void:
	var panel_w: float = _vw * 0.6
	var panel_h: float = _vh * 0.62
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var inner := _build_margin_vbox(panel, 0.025, 0.016)
	_build_face_body(inner, CardRegistry.get_template(_card.template_id if _card != null else ""), _card, true)

	var close_btn := _UiUtil.make_button("Close", Vector2(_vh * 0.18, _vh * 0.055), int(_font(0.025)), _close)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(close_btn)
	inner.add_child(btn_row)

# Dual-face layout: Light and Dark faces side by side.
func _build_dual_face_ui() -> void:
	var total_w: float = minf(_vw * 0.92, _vh * 1.2)
	var panel_h: float = _vh * 0.78
	var panel := _build_centered_panel(total_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var outer_vbox := _UiUtil.make_vbox(int(_vh * 0.012))
	var outer_margin := _UiUtil.make_margin(int(_vh * 0.018), int(_vh * 0.018), int(_vh * 0.018), int(_vh * 0.018), panel)
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_child(outer_vbox)

	# Header
	var header_lbl := _UiUtil.make_label("Dual-Faced Card", int(_font(0.028)))
	header_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(header_lbl)

	# Two face panels side by side
	var hbox := _UiUtil.make_hbox(int(_vh * 0.012), outer_vbox)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var light_tmpl: Dictionary = CardRegistry.get_template_for_face(_card.dual_card_id, "light")
	var dark_tmpl: Dictionary = CardRegistry.get_template_for_face(_card.dual_card_id, "dark")
	var active: String = _card.active_face if _card.active_face != "" else "light"

	_build_face_panel(hbox, light_tmpl, _card, active == "light", "Light")
	_build_face_panel(hbox, dark_tmpl, _card, active == "dark", "Dark")

	var close_btn := _UiUtil.make_button("Close", Vector2(_vh * 0.18, _vh * 0.055), int(_font(0.025)), _close)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(close_btn)
	outer_vbox.add_child(btn_row)

func _build_face_panel(parent: HBoxContainer, tmpl: Dictionary, card: CardInstance, is_active: bool, face_label: String) -> void:
	var face_panel := PanelContainer.new()
	face_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	face_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fs := _UiUtil.make_style(Color(0.08, 0.08, 0.18, 0.9), 6)
	if is_active:
		fs.border_color = Color(0.4, 1.0, 0.6)
		fs.set_border_width_all(3)
	face_panel.add_theme_stylebox_override("panel", fs)
	parent.add_child(face_panel)

	var margin := _UiUtil.make_margin(int(_vh * 0.012), int(_vh * 0.012), int(_vh * 0.012), int(_vh * 0.012), face_panel)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := _UiUtil.make_vbox(int(_vh * 0.006), margin)

	# Face tag
	var tag_lbl := _UiUtil.make_label(face_label + (" (Active)" if is_active else ""), int(_font(0.019)))
	tag_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6) if is_active else Color(0.65, 0.65, 0.75))
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tag_lbl)

	_build_face_body(vbox, tmpl, card if is_active else null, false)

func _build_face_body(container: VBoxContainer, tmpl: Dictionary, card: CardInstance, show_status: bool) -> void:
	# Color bar
	var color_bar := ColorRect.new()
	color_bar.custom_minimum_size = Vector2(0, _vh * 0.006)
	color_bar.color = tmpl.get("color", Color(0.4, 0.4, 0.4)) if not tmpl.is_empty() else Color(0.4, 0.4, 0.4)
	container.add_child(color_bar)

	# Illustration — same texture the small card view shows, enlarged.
	# 32×32 pixel art needs nearest filtering or it smears at this size.
	var illus: Texture2D = null
	if not tmpl.is_empty():
		illus = tmpl.get("illustration") as Texture2D
	if illus != null:
		var art := TextureRect.new()
		art.texture = illus
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.custom_minimum_size = Vector2(0.0, _vh * (0.14 if show_status else 0.09))
		container.add_child(art)

	# Name
	var name_lbl := _UiUtil.make_label(str(tmpl.get("name", "?")) if not tmpl.is_empty() else (card.name if card != null else "?"), int(_font(0.030)))
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_lbl)

	# Class / type row
	var cc: String = str(tmpl.get("card_class", "")) if not tmpl.is_empty() else (card.card_class if card != null else "")
	var mt: String = str(tmpl.get("magic_type", "")) if not tmpl.is_empty() else ""
	var mb_val: String = str(tmpl.get("magic_branch", "")) if not tmpl.is_empty() else ""
	var class_text: String = cc.capitalize()
	if cc == "spell":
		if mt != "":
			class_text += "  ·  " + mt.capitalize()
		if mb_val != "":
			class_text += " / " + mb_val.capitalize()
	var class_lbl := _UiUtil.make_label(class_text, int(_font(0.018)))
	class_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(class_lbl)

	# Stats
	var cost_v: int = int(tmpl.get("cost", 0)) if not tmpl.is_empty() else (card.cost if card != null else 0)
	var atk_v: int = int(tmpl.get("attack", 0)) if not tmpl.is_empty() else (card.attack if card != null else 0)
	var hp_v: int = int(tmpl.get("health", 0)) if not tmpl.is_empty() else (card.health if card != null else 0)
	var stats_lbl := Label.new()
	if cc == "minion":
		stats_lbl.text = "Cost %d   ·   %d / %d" % [cost_v, atk_v, hp_v]
	else:
		stats_lbl.text = "Cost %d" % cost_v
	stats_lbl.add_theme_font_size_override("font_size", _font(0.022))
	stats_lbl.add_theme_color_override("font_color", Color.WHITE)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(stats_lbl)

	var sep := HSeparator.new()
	container.add_child(sep)

	# Description
	var desc: String = str(tmpl.get("description", "")) if not tmpl.is_empty() else (card.description if card != null else "")
	var desc_lbl := _UiUtil.make_label(desc, int(_font(0.019)))
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(desc_lbl)

	# Spell effect
	var se: String = str(tmpl.get("spell_effect", "")) if not tmpl.is_empty() else (card.spell_effect if card != null else "")
	var sp: int = int(tmpl.get("spell_power", 0)) if not tmpl.is_empty() else (card.spell_power if card != null else 0)
	if cc == "spell" and se != "":
		var effect_lbl := Label.new()
		effect_lbl.text = SpellEffectLabels.spell(se, sp)
		effect_lbl.add_theme_font_size_override("font_size", _font(0.018))
		effect_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
		effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(effect_lbl)

	# Keywords
	var kws_raw = tmpl.get("keywords", []) if not tmpl.is_empty() else (card.keywords if card != null else [])
	var kws: Array[String] = []
	kws.assign(kws_raw)
	if not kws.is_empty():
		var kw_sep := HSeparator.new()
		container.add_child(kw_sep)
		var kw_descs: Dictionary = {
			Keywords.WARD:   "Enemy attacks must target this minion first.",
			Keywords.SURGE:  "Can attack the turn it is summoned.",
			Keywords.SHROUD: "Absorbs the first hit.",
		}
		for kw: String in kws:
			var base_desc: String = str(kw_descs.get(kw, kw))
			if kw == Keywords.SHROUD and card != null and show_status:
				base_desc += " (" + ("Active" if card.shroud_active else "Consumed") + ")"
			var kw_lbl := _UiUtil.make_label(kw.capitalize() + " — " + base_desc, int(_font(0.017)))
			kw_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
			kw_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			kw_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			container.add_child(kw_lbl)

	# Emergence
	var ee: String = str(tmpl.get("emergence_effect", "")) if not tmpl.is_empty() else (card.emergence_effect if card != null else "")
	var ep: int = int(tmpl.get("emergence_power", 0)) if not tmpl.is_empty() else (card.emergence_power if card != null else 0)
	if ee != "":
		var em_sep := HSeparator.new()
		container.add_child(em_sep)
		var em_lbl := Label.new()
		em_lbl.text = SpellEffectLabels.emergence(ee, ep)
		em_lbl.add_theme_font_size_override("font_size", _font(0.018))
		em_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		em_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		em_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(em_lbl)

	# Status effects (only for the active card instance)
	if card != null and show_status:
		var effects: Array[String] = ["poison", "armor", "freeze", "stun"]
		var colors: Array[Color] = [Color.GREEN, Color.CORNFLOWER_BLUE, Color.CYAN, Color.YELLOW]
		var labels: Array[String] = ["Poison", "Armor", "Freeze", "Stun"]
		for i in range(effects.size()):
			if not card.has_status(effects[i]):
				continue
			var st_lbl := _UiUtil.make_label("%s: %d" % [labels[i], card.get_status_value(effects[i])], int(_font(0.019)))
			st_lbl.add_theme_color_override("font_color", colors[i])
			st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			container.add_child(st_lbl)

func _close() -> void:
	closed.emit()
	queue_free()
