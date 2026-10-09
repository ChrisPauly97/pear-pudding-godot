## Card-face backpack tile (GID-148). Replaces the bare coloured square with a
## mini card: cost gem, rarity-coloured frame, monogram art, name and ATK/HP,
## so every item in the bag reads at a glance. Pure view — the caller wires input.
extends RefCounted

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const VeterancyUtil = preload("res://game_logic/VeterancyUtil.gd")
const CardFace = preload("res://scenes/ui/CardFace.gd")

const _SELECTED_TINT := Color(0.7, 1.25, 0.75)
const _HOVER_TINT := Color(1.25, 1.25, 1.25)
const _ATK := Color(1.0, 0.78, 0.30)
const _HP := Color(1.0, 0.42, 0.42)
## Veterans wear their history: a bronze, silver then gold edge by rank (GID-180 / TID-739).
const GILD_COLORS: Array[Color] = [Color(0.8, 0.5, 0.25), Color(0.85, 0.88, 0.95), Color(1.0, 0.82, 0.25)]

## Tile size for a given layout reference length (min of viewport w/h).
static func tile_size(ref: float) -> Vector2:
	return Vector2(ref * 0.13, ref * 0.175)

## `tag` is a short corner note (e.g. the deck the card sits in); `selected`
## draws the bulk-select check; `dimmed` greys out a tile that can't be picked.
static func build(inst: Dictionary, tmpl: Dictionary, ref: float, tag: String = "",
		selected: bool = false, dimmed: bool = false) -> Button:
	var rarity: String = str(inst.get("rarity", "common"))
	var rcol: Color = _UiUtil.rarity_color(rarity)
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	var tid: String = str(inst.get("template_id", ""))
	var card_name: String = VeterancyUtil.display_name(inst, str(tmpl.get("name", tid)))
	var is_spell: bool = str(tmpl.get("card_class", "minion")) == "spell"
	var sz: Vector2 = tile_size(ref)

	var tile := Button.new()
	tile.custom_minimum_size = sz
	tile.focus_mode = Control.FOCUS_NONE
	tile.tooltip_text = "%s\n%s" % [card_name, str(tmpl.get("description", ""))]
	# Framed like a battle card (GID-151); tinted copies mark hover / selection.
	var frame: StyleBoxTexture = CardFace.frame_style(str(tmpl.get("magic_type", "")), sz.y)
	var sb := frame.duplicate() as StyleBoxTexture
	if selected:
		sb.modulate_color = _SELECTED_TINT
	var sb_hover := frame.duplicate() as StyleBoxTexture
	sb_hover.modulate_color = _SELECTED_TINT if selected else _HOVER_TINT
	for st: String in ["normal", "focus", "pressed"]:
		tile.add_theme_stylebox_override(st, sb)
	tile.add_theme_stylebox_override("hover", sb_hover)
	tile.material = CardFace.foil_material(rarity)
	if dimmed:
		tile.modulate = Color(0.55, 0.55, 0.55)

	var pad: float = sb.content_margin_left
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = pad
	box.offset_right = -pad
	box.offset_top = pad
	box.offset_bottom = -pad * 0.5
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)

	box.add_child(_art(tmpl, card_name, card_color, rcol, ref))

	var name_lbl := _label(card_name, int(ref * 0.017), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, box)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var stats := HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", int(ref * 0.012))
	box.add_child(stats)
	if is_spell:
		_label("Spell", int(ref * 0.016), Color(0.75, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER, stats)
	else:
		_label("⚔%d" % int(inst.get("attack", 0)), int(ref * 0.018), _ATK, HORIZONTAL_ALIGNMENT_CENTER, stats)
		_label("♥%d" % int(inst.get("health", 0)), int(ref * 0.018), _HP, HORIZONTAL_ALIGNMENT_CENTER, stats)

	# ---- Overlays (absolute) ----
	var gem := CardFace.make_badge("cost", str(int(inst.get("cost", 0))), ref * 0.036, int(ref * 0.018))
	gem.position = Vector2(pad * 0.4, pad * 0.4)
	tile.add_child(gem)

	var rlbl := _label(rarity.substr(0, 1).to_upper(), int(ref * 0.016), rcol, HORIZONTAL_ALIGNMENT_RIGHT, tile)
	rlbl.position = Vector2(sz.x - ref * 0.028, pad * 0.3)

	var rank: int = VeterancyUtil.rank_for(int(inst.get("kills", 0)), int(inst.get("battles_survived", 0)))
	if rank > 0:
		_gild(tile, rank, ref)
		var chev := _label(VeterancyUtil.rank_chevrons(rank), int(ref * 0.014), Color(1.0, 0.82, 0.2),
				HORIZONTAL_ALIGNMENT_RIGHT, tile)
		chev.position = Vector2(sz.x - ref * 0.03, ref * 0.03)

	if tag != "":
		var tag_lbl := _label(tag, int(ref * 0.013), Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, tile)
		tag_lbl.position = Vector2(0.0, sz.y * 0.40)
		tag_lbl.size = Vector2(sz.x, ref * 0.02)
		tag_lbl.clip_text = true
		tag_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		tag_lbl.add_theme_constant_override("outline_size", maxi(2, int(ref * 0.004)))

	if selected:
		var check := _label("✓", int(ref * 0.05), Color(0.45, 1.0, 0.55), HORIZONTAL_ALIGNMENT_CENTER, tile)
		check.position = Vector2(0.0, sz.y * 0.12)
		check.size = Vector2(sz.x, ref * 0.06)
		check.add_theme_color_override("font_outline_color", Color.BLACK)
		check.add_theme_constant_override("outline_size", maxi(3, int(ref * 0.006)))
	return tile

## Gilded edge by veterancy rank.
static func _gild(tile: Control, rank: int, ref: float) -> void:
	var edge := Panel.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col: Color = GILD_COLORS[clampi(rank - 1, 0, GILD_COLORS.size() - 1)]
	edge.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0, 0, 0, 0), int(ref * 0.008), col,
			maxi(2, int(ref * (0.002 + 0.0012 * rank)))))
	tile.add_child(edge)

## "×N" pill for a binder stack of N copies.
static func add_count(tile: Control, n: int, ref: float) -> void:
	if n <= 1:
		return
	var sz: Vector2 = tile_size(ref)
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.05, 0.05, 0.08, 0.85), int(ref * 0.01),
			Color(1, 1, 1, 0.5), 1))
	var lbl := _label("×%d" % n, int(ref * 0.018), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, pill)
	lbl.add_theme_constant_override("outline_size", 0)
	tile.add_child(pill)
	pill.position = Vector2(sz.x - ref * 0.05, sz.y * 0.47)

## Gold star for a perfect roll (top of every stat's band); CardJuice twinkles it.
static func add_perfect_mark(tile: Control, ref: float) -> Label:
	var sz: Vector2 = tile_size(ref)
	var star := _label("✦", int(ref * 0.03), Color(1.0, 0.88, 0.35), HORIZONTAL_ALIGNMENT_CENTER, tile)
	star.tooltip_text = "Perfect roll"
	star.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.0))
	star.add_theme_constant_override("outline_size", maxi(2, int(ref * 0.004)))
	star.position = Vector2(sz.x * 0.5 - ref * 0.018, -ref * 0.004)
	return star

## Dark silhouette of a card the player has not found yet (binder pages).
static func build_silhouette(tid: String, tmpl: Dictionary, ref: float) -> Button:
	var fake: Dictionary = {"template_id": tid, "rarity": "common", "attack": int(tmpl.get("attack", 0)),
		"health": int(tmpl.get("health", 0)), "cost": int(tmpl.get("cost", 0))}
	var tile: Button = build(fake, tmpl, ref)
	tile.material = null
	tile.modulate = Color(0.32, 0.32, 0.38)
	var box := tile.get_child(0) as Control
	if box != null and box.get_child_count() > 0:
		(box.get_child(0) as CanvasItem).modulate = Color(0, 0, 0, 0.92)
	var q := _label("?", int(ref * 0.06), Color(0.85, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, tile)
	q.size = Vector2(tile_size(ref).x, ref * 0.08)
	q.position = Vector2(0.0, tile_size(ref).y * 0.18)
	tile.tooltip_text = "%s — not found yet" % str(tmpl.get("name", tid))
	return tile

## The picture area: the card's illustration when it has one, otherwise a
## monogram on the card colour so similar tiles still differ at a glance.
static func _art(tmpl: Dictionary, card_name: String, card_color: Color, rcol: Color, ref: float) -> Control:
	var illus: Texture2D = tmpl.get("illustration") as Texture2D
	if illus != null:
		var art := CardFace.make_art(illus, 0.0)
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		CardFace.set_art_background(art, str(tmpl.get("magic_branch", "")), tile_size(ref).y)
		return art
	var plate := PanelContainer.new()
	plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _UiUtil.make_style(card_color.darkened(0.15), int(ref * 0.008),
			rcol.darkened(0.4), 1))
	var mono := _label(card_name.substr(0, 1).to_upper(), int(ref * 0.05), card_color.lightened(0.6),
			HORIZONTAL_ALIGNMENT_CENTER, plate)
	mono.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return plate

static func _label(text: String, font_size: int, tint: Color, align: HorizontalAlignment, parent: Node) -> Label:
	var lbl := _UiUtil.make_label(text, font_size, tint, align, parent)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
