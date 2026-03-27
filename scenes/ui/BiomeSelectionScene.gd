extends Control

const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")

const _NAMES: Array[String] = [
	"Flowering\nGrasslands",
	"Lush\nForest",
	"Stark\nDesert",
	"Scorched\nLands",
	"Snowy\nMountains",
]

const _TAGLINES: Array[String] = [
	"Open meadows,\ngentle rolling hills.",
	"Dense trees,\nshadowed paths.",
	"Vast flat dunes,\nbaking heat.",
	"Jagged spires,\ncharred earth.",
	"Towering peaks,\nbitter cold.",
]

const _CARD_BG: Array[Color] = [
	Color(0.10, 0.28, 0.05),   # Grasslands
	Color(0.05, 0.15, 0.04),   # Forest
	Color(0.32, 0.22, 0.05),   # Desert
	Color(0.22, 0.04, 0.01),   # Scorched
	Color(0.15, 0.22, 0.35),   # Mountains
]

func _ready() -> void:
	var vh: float = get_viewport().get_visible_rect().size.y

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.10)
	add_child(bg)

	# Root VBoxContainer fills the screen and drives all layout — no manual positioning
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Top padding
	var top_pad := Control.new()
	top_pad.custom_minimum_size = Vector2(0, int(vh * 0.04))
	root.add_child(top_pad)

	# Title
	var title := Label.new()
	title.text = "Choose Your World"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, int(vh * 0.12))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(vh * 0.062))
	root.add_child(title)

	# CenterContainer holds the card row and expands to fill remaining space
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(vh * 0.022))
	center.add_child(hbox)

	var card_w: float = vh * 0.19
	var card_h: float = vh * 0.62

	for i in range(BiomeDef.COUNT):
		hbox.add_child(_make_card(i, card_w, card_h, vh))

	# Bottom bar — back button left-aligned, fixed height
	var bottom_bar := HBoxContainer.new()
	bottom_bar.custom_minimum_size = Vector2(0, int(vh * 0.11))
	bottom_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	bottom_bar.add_theme_constant_override("separation", 0)
	root.add_child(bottom_bar)

	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(int(vh * 0.03), 0)
	bottom_bar.add_child(left_pad)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(int(vh * 0.16), int(vh * 0.07))
	back_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
	back_btn.pressed.connect(_on_back)
	bottom_bar.add_child(back_btn)

func _make_card(biome_id: int, card_w: float, card_h: float, vh: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(card_w, card_h)

	var style := StyleBoxFlat.new()
	style.bg_color = _CARD_BG[biome_id]
	for side in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		style.set_border_width(side, 2)
	style.border_color = Color(1.0, 1.0, 1.0, 0.18)
	for corner in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT]:
		style.set_corner_radius(corner, 6)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(vh * 0.012))
	panel.add_child(vbox)

	# Color swatch strip at top
	var swatch := ColorRect.new()
	var gt: Color = BiomeDef.GRASS_TINT[biome_id]
	swatch.color = Color(gt.r * 0.65, gt.g * 0.65, gt.b * 0.65)
	swatch.custom_minimum_size = Vector2(0, int(vh * 0.12))
	vbox.add_child(swatch)

	# Biome name
	var name_lbl := Label.new()
	name_lbl.text = _NAMES[biome_id]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", int(vh * 0.030))
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	# Separator line
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(1, 1, 1, 0.15))
	vbox.add_child(sep)

	# Tagline
	var tag_lbl := Label.new()
	tag_lbl.text = _TAGLINES[biome_id]
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag_lbl.add_theme_font_size_override("font_size", int(vh * 0.022))
	tag_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	vbox.add_child(tag_lbl)

	# Spacer pushes button to bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# "Venture Here" button
	var btn := Button.new()
	btn.text = "Venture Here"
	btn.custom_minimum_size = Vector2(0, int(vh * 0.065))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", int(vh * 0.024))
	var captured_id := biome_id
	btn.pressed.connect(func() -> void: _on_biome_chosen(captured_id))
	vbox.add_child(btn)

	# Bottom padding
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, int(vh * 0.015))
	vbox.add_child(pad)

	return panel

func _on_biome_chosen(biome_id: int) -> void:
	SceneManager.start_new_game_with_biome(biome_id)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MenuScene.tscn")
