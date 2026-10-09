## Forge effects for the deck table (GID-180 / TID-742): a scrapped card burns
## away and its essence sparks fly to the wallet. Statics; every node it makes
## frees itself.
extends RefCounted

const _CardTile = preload("res://scenes/ui/inventory/CardTile.gd")
const _CardJuice = preload("res://scenes/ui/inventory/CardJuice.gd")

const ESSENCE := Color(0.5, 0.85, 1.0)
const EMBER := Color(1.6, 0.75, 0.3)


## Burns a copy of the card at `from` (global rect) inside `layer`, then sends
## `sparks` essence motes to `to` (global point).
static func burn(layer: Control, inst: Dictionary, tmpl: Dictionary, from: Rect2, to: Vector2, ref: float,
		sparks: int = 8) -> void:
	if not layer.is_inside_tree():
		return
	var tile: Button = _CardTile.build(inst, tmpl, ref)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.top_level = true
	tile.z_index = 30
	layer.add_child(tile)
	tile.global_position = from.position
	tile.size = tile.custom_minimum_size
	tile.pivot_offset = tile.size * 0.5
	_CardJuice.sparkle(tile, "legendary", ref)
	_CardJuice.sound("burn")
	var tw := tile.create_tween()
	tw.tween_property(tile, "modulate", EMBER, 0.15)
	tw.tween_property(tile, "scale", Vector2(0.55, 0.55), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tile, "rotation", 0.35, 0.4)
	tw.parallel().tween_property(tile, "modulate:a", 0.0, 0.4)
	tw.tween_callback(tile.queue_free)
	var centre: Vector2 = from.get_center()
	for i in range(sparks):
		var mote := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = ESSENCE
		sb.set_corner_radius_all(int(ref * 0.01))
		mote.add_theme_stylebox_override("panel", sb)
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.top_level = true
		mote.z_index = 31
		mote.size = Vector2(ref * 0.014, ref * 0.014)
		layer.add_child(mote)
		var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * ref * 0.05
		mote.global_position = centre + jitter
		var mt := mote.create_tween()
		mt.tween_interval(0.2 + 0.05 * i)
		mt.tween_property(mote, "global_position", to, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		mt.parallel().tween_property(mote, "scale", Vector2(0.4, 0.4), 0.5)
		mt.tween_callback(mote.queue_free)
