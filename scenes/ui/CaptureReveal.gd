## CaptureReveal — the soulbind "you caught it" moment (GID-188 / TID-796).
##
## A card back that rises, flips edge-on and opens on the captured card's face
## (frame, art, name, attack / health), with a glow pulse in the card's branch
## colour and a line that sends the player to the Deck Table. The pack-opening
## flip (PackOpenScene._flip_card) at a single, bigger card.
##
## `CaptureReveal.new()`, `setup(card_id, vh)`, add it to a container, then
## `play(calm)` once it is in the tree. No autoloads, so `-s` scripts can load it.
extends Control

const _CardFace = preload("res://scenes/ui/CardFace.gd")
const _CardRegistry = preload("res://autoloads/CardRegistry.gd")
const _MagicTypes = preload("res://game_logic/MagicTypes.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

## Seconds: rise-in, hold on the back, each half of the flip, glow pulse.
const RISE_S: float = 0.35
const HOLD_S: float = 0.35
const FLIP_HALF_S: float = 0.16
const GLOW_S: float = 0.6
## Glow alpha the card settles at after the pulse.
const REST_GLOW: float = 0.45
## Card height as a fraction of viewport height (width follows the 5:7 card ratio).
const CARD_H_FRAC: float = 0.3
const DECK_HINT: String = "Added to your collection — slot it into your deck at the Deck Table."

var card_id: String = ""
var _vh: float = 720.0
var _back: PanelContainer
var _face: PanelContainer
var _glow: Panel
var _hint: Label

func setup(p_card_id: String, vh: float) -> void:
	card_id = p_card_id
	_vh = vh
	var card_h: float = vh * CARD_H_FRAC
	var card_size := Vector2(card_h * 5.0 / 7.0, card_h)
	var hint_h: float = vh * 0.08
	custom_minimum_size = Vector2(maxf(card_size.x, vh * 0.6), card_h + hint_h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tmpl: Dictionary = _CardRegistry.get_template(card_id)

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = card_size
	holder.position = Vector2((custom_minimum_size.x - card_size.x) * 0.5, 0.0)
	holder.pivot_offset = card_size * 0.5
	add_child(holder)

	_glow = Panel.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad: float = card_h * 0.06
	_glow.position = Vector2(-pad, -pad)
	_glow.size = card_size + Vector2(pad, pad) * 2.0
	var glow_col: Color = card_color(tmpl)
	_glow.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(glow_col, 0.9), int(card_h * 0.06)))
	_glow.modulate.a = 0.0
	holder.add_child(_glow)

	_back = PanelContainer.new()
	_back.size = card_size
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_CardFace.apply_back(_back, card_h)
	holder.add_child(_back)

	_face = PanelContainer.new()
	_face.size = card_size
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_theme_stylebox_override("panel", _CardFace.frame_style(str(tmpl.get("magic_type", "")), card_h))
	_face.visible = false
	holder.add_child(_face)
	_build_face(tmpl, card_h)

	_hint = _UiUtil.make_label(DECK_HINT, int(vh * 0.022), Color(0.85, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER, self)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.position = Vector2(0.0, card_h + pad + vh * 0.012)
	_hint.size = Vector2(custom_minimum_size.x, hint_h)
	_hint.modulate.a = 0.0

func _build_face(tmpl: Dictionary, card_h: float) -> void:
	var m: int = int(card_h * 0.07)
	var vbox := _UiUtil.make_vbox(int(card_h * 0.02), _UiUtil.make_margin(m, m, m, m, _face))
	var illus: Texture2D = tmpl.get("illustration") as Texture2D
	if illus != null:
		var art := _CardFace.make_art(illus, card_h * 0.45)
		_CardFace.set_art_background(art, str(tmpl.get("magic_branch", "")), card_h)
		vbox.add_child(art)
	var name_lbl := _UiUtil.make_label(str(tmpl.get("name", card_id)), int(card_h * 0.075), Color(1.0, 0.92, 0.6),
			HORIZONTAL_ALIGNMENT_CENTER, vbox)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if str(tmpl.get("card_class", "")) == "spell":
		return
	var stats := _UiUtil.make_hbox(int(card_h * 0.04), vbox)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	var d: float = card_h * 0.16
	var fs: int = int(card_h * 0.08)
	stats.add_child(_CardFace.make_badge("atk", str(int(tmpl.get("attack", 0))), d, fs))
	stats.add_child(_CardFace.make_badge("hp", str(int(tmpl.get("health", 0))), d, fs))

## The card's branch colour (white-gold for cards without a branch).
static func card_color(tmpl: Dictionary) -> Color:
	var branch: String = str(tmpl.get("magic_branch", ""))
	return _MagicTypes.branch_color(branch) if branch != "" else Color(1.0, 0.85, 0.45)

## Rise → hold on the back → flip to the face → glow pulse → deck hint.
## `calm` (Settings > Reduce Flashing) halves the glow peak.
func play(calm: bool = false) -> void:
	var holder: Control = _back.get_parent() as Control
	holder.scale = Vector2(0.6, 0.6)
	holder.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "scale", Vector2.ONE, RISE_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "modulate:a", 1.0, RISE_S * 0.6)
	tw.set_parallel(false)
	tw.tween_interval(HOLD_S)
	tw.tween_property(holder, "scale:x", 0.0, FLIP_HALF_S).set_ease(Tween.EASE_IN)
	tw.tween_callback(show_face)
	tw.tween_property(holder, "scale:x", 1.0, FLIP_HALF_S).set_ease(Tween.EASE_OUT)
	var peak: float = 0.5 if calm else 1.0
	tw.tween_property(_glow, "modulate:a", peak, GLOW_S * 0.3)
	tw.tween_property(_glow, "modulate:a", REST_GLOW, GLOW_S * 0.7)
	tw.parallel().tween_property(_hint, "modulate:a", 1.0, GLOW_S * 0.7)

## Jumps straight to the face (also the flip's midpoint).
func show_face() -> void:
	_back.visible = false
	_face.visible = true

func is_face_up() -> bool:
	return _face.visible
