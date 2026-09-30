## Framed card faces (GID-151 / TID-632). Turns the CardChrome pixel art into
## sized pieces every card view shares: the magic-type frame and the card back
## (9-sliced styleboxes, upscaled by a whole number so the border stays crisp),
## the crest, the cost gem / attack / health badges and the text plate.
## Battle cards (CardViewBuilder), backpack tiles (CardTile), pack opening and
## the inspect overlay all build their chrome here.
extends RefCounted

const CardChrome = preload("res://game_logic/CardChrome.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _FOIL_SHADER := preload("res://assets/shaders/card_foil.gdshader")

## Card height (px) per whole-number upscale step of the 48 px frame.
const PX_PER_SCALE := 110.0
const BADGE_OUTLINE := Color(0.05, 0.05, 0.08)
## Foil strength by rarity (TID-641); rarities not listed get no foil.
const FOIL_STRENGTH: Dictionary = {"epic": 0.35, "legendary": 0.55}

static var _scaled: Dictionary = {}   # "<rid>|<k>" -> Texture2D
static var _styles: Dictionary = {}   # "<kind>|<key>|<k>" -> StyleBoxTexture
static var _foils: Dictionary = {}    # rarity -> ShaderMaterial


## Whole-number upscale for a card `card_h` px tall.
static func pixel_scale(card_h: float) -> int:
	return maxi(1, roundi(card_h / PX_PER_SCALE))

## `tex` upscaled `k`× with nearest filtering (cached). Falls back to `tex`
## when its pixels can't be read (e.g. the headless dummy renderer).
static func upscaled(tex: Texture2D, k: int) -> Texture2D:
	if tex == null or k <= 1:
		return tex
	var key: String = "%d|%d" % [tex.get_rid().get_id(), k]
	if _scaled.has(key):
		return _scaled[key] as Texture2D
	var out: Texture2D = tex
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		img = img.duplicate() as Image
		if img.is_compressed():
			img.decompress()
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		out = ImageTexture.create_from_image(img)
	_scaled[key] = out
	return out

## 9-slice stylebox over `tex`: `margin` source px of border, content inset by
## the same so children sit inside the border.
static func _nine_slice(kind: String, tex: Texture2D, margin: int, k: int, tile: bool) -> StyleBoxTexture:
	var key: String = "%s|%d|%d" % [kind, tex.get_rid().get_id(), k]
	if _styles.has(key):
		return _styles[key] as StyleBoxTexture
	var sb := StyleBoxTexture.new()
	sb.texture = upscaled(tex, k)
	# Margins are in the (possibly upscaled) texture's own pixels.
	var m: float = float(margin) * float(sb.texture.get_width()) / float(tex.get_width())
	sb.set_texture_margin_all(m)
	sb.set_content_margin_all(m)
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	_styles[key] = sb
	return sb

## The frame for a card of `magic_type` (neutral when empty / unknown).
static func frame_style(magic_type: String, card_h: float) -> StyleBoxTexture:
	return _nine_slice("frame", CardChrome.frame_texture(magic_type), CardChrome.FRAME_MARGIN,
			pixel_scale(card_h), false)

## The shared card back (lattice centre tiles instead of stretching).
static func back_style(card_h: float) -> StyleBoxTexture:
	return _nine_slice("back", CardChrome.back_texture(), CardChrome.FRAME_MARGIN, pixel_scale(card_h), true)

## Dark plate behind ability text.
static func plate_style(card_h: float) -> StyleBoxTexture:
	return _nine_slice("plate", CardChrome.plate_texture(), CardChrome.PLATE_MARGIN, pixel_scale(card_h), false)

## Dresses `panel` as a face-down card: back stylebox + centred crest.
static func apply_back(panel: PanelContainer, card_h: float) -> void:
	panel.add_theme_stylebox_override("panel", back_style(card_h))
	if panel.get_node_or_null("BackCrest") != null:
		return
	var crest := TextureRect.new()
	crest.name = "BackCrest"
	crest.texture = CardChrome.crest_texture()
	crest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(crest)

## A number on a round badge: kind "cost" (mana gem), "atk" or "hp".
static func make_badge(kind: String, text: String, diameter: float, font_size: int) -> Label:
	var tex: Texture2D = CardChrome.gem_texture()
	if kind == "atk":
		tex = CardChrome.attack_badge_texture()
	elif kind == "hp":
		tex = CardChrome.health_badge_texture()
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_content_margin_all(0.0)
	var lbl := Label.new()
	lbl.set_meta("badge_font_size", font_size)
	lbl.custom_minimum_size = Vector2(diameter, diameter)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_stylebox_override("normal", sb)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", BADGE_OUTLINE)
	lbl.add_theme_constant_override("outline_size", maxi(2, int(font_size * 0.25)))
	set_badge_text(lbl, text)
	return lbl

## Sets a badge's number, shrinking the font for 3+ digits (real-time costs
## are mana points ×100) so it stays on the badge.
static func set_badge_text(lbl: Label, text: String) -> void:
	var base: int = int(lbl.get_meta("badge_font_size", 16))
	lbl.text = text
	var fs: int = base if text.length() <= 2 else int(base * 2.2 / float(text.length()))
	lbl.add_theme_font_size_override("font_size", maxi(8, fs))

## Puts the branch's tiled background behind an illustration rect (reused
## panels swap it in place). `card_h` picks the pixel scale.
static func set_art_background(art: TextureRect, branch: String, card_h: float) -> void:
	var bg: TextureRect = art.get_node_or_null("ArtBackground") as TextureRect
	if bg == null:
		bg = TextureRect.new()
		bg.name = "ArtBackground"
		bg.show_behind_parent = true
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.stretch_mode = TextureRect.STRETCH_TILE
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.add_child(bg)
	bg.texture = upscaled(CardChrome.background_texture(branch), pixel_scale(card_h))

## Pixel-art illustration rect (nearest filtering; 32 px art smears otherwise).
static func make_art(tex: Texture2D, height: float) -> TextureRect:
	var art := TextureRect.new()
	art.texture = tex
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(0.0, height)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art

## Shared foil material for `rarity` (epic / legendary), else null. Set it as
## a card panel's `material`: it lights the frame, not the contents.
static func foil_material(rarity: String) -> ShaderMaterial:
	if not FOIL_STRENGTH.has(rarity):
		return null
	if not _foils.has(rarity):
		var mat := ShaderMaterial.new()
		mat.shader = _FOIL_SHADER
		mat.set_shader_parameter("tint", _UiUtil.rarity_color(rarity))
		mat.set_shader_parameter("strength", float(FOIL_STRENGTH[rarity]))
		_foils[rarity] = mat
	return _foils[rarity] as ShaderMaterial

## A small rarity-coloured diamond on the frame's top edge (rare and up);
## call from the card panel's draw signal.
static func draw_rarity_pip(panel: Control, rarity: String) -> void:
	if rarity == "" or rarity == "common":
		return
	var r: float = maxf(4.0, panel.size.y * 0.025)
	var c := Vector2(panel.size.x * 0.5, r * 0.9)
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	panel.draw_colored_polygon(pts, BADGE_OUTLINE)
	var inner := PackedVector2Array()
	for p: Vector2 in pts:
		inner.append(c + (p - c) * 0.65)
	panel.draw_colored_polygon(inner, _UiUtil.rarity_color(rarity))
