## Feel for the deck table (GID-180 / TID-738): lifted drag previews, rarity
## sparkles, pop-ins, legendary shimmer and card sounds. Statics over plain
## Controls so InventoryScene, DeckPile and the forge share one look.
extends RefCounted

const _CardTile = preload("res://scenes/ui/inventory/CardTile.gd")
const _DragCardPreview = preload("res://scenes/ui/inventory/DragCardPreview.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

## Sparkle particle count per rarity tier (common → legendary).
const SPARKLE_AMOUNT: Array[int] = [6, 12, 20, 34]
const SHIMMER_META := &"legend_shimmer"


## A lifted, tilting copy of the card for `Control.set_drag_preview`.
static func drag_preview(inst: Dictionary, tmpl: Dictionary, ref: float) -> Control:
	var holder: Control = _DragCardPreview.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(holder as _DragCardPreview).setup(_CardTile.build(inst, tmpl, ref), ref)
	return holder


## One-shot burst of rarity-coloured sparks centred on `ctrl`; frees itself.
static func sparkle(ctrl: Control, rarity: String, ref: float) -> void:
	if not ctrl.is_inside_tree():
		return
	var tier: int = clampi(IsoConst.RARITY_ORDER.find(rarity), 0, SPARKLE_AMOUNT.size() - 1)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = SPARKLE_AMOUNT[tier]
	p.lifetime = 0.55 + 0.1 * tier
	p.explosiveness = 0.9
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, ref * 0.35)
	p.initial_velocity_min = ref * 0.08
	p.initial_velocity_max = ref * (0.16 + 0.04 * tier)
	p.scale_amount_min = ref * 0.003
	p.scale_amount_max = ref * (0.006 + 0.002 * tier)
	p.color = _UiUtil.rarity_color(rarity).lightened(0.25)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.position = ctrl.size * 0.5
	p.z_index = 10
	ctrl.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Scale punch: the control lands with a little bounce.
static func pop(ctrl: Control, strength: float = 0.18) -> void:
	if not ctrl.is_inside_tree():
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	ctrl.scale = Vector2.ONE * (1.0 + strength)
	var tw := ctrl.create_tween()
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Slow glow pulse on a legendary tile. Idempotent; the tween dies with the tile.
static func shimmer(tile: Control, rarity: String) -> void:
	if rarity != "legendary" or not tile.is_inside_tree() or tile.has_meta(SHIMMER_META):
		return
	tile.set_meta(SHIMMER_META, true)
	var tw := tile.create_tween().set_loops()
	tw.tween_property(tile, "self_modulate", Color(1.25, 1.18, 0.9), 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tile, "self_modulate", Color.WHITE, 1.1).set_trans(Tween.TRANS_SINE)


## Slow twinkle for the perfect-roll star. Call once it is in the tree; idempotent.
static func twinkle(ctrl: Control) -> void:
	if not ctrl.is_inside_tree() or ctrl.has_meta(SHIMMER_META):
		return
	ctrl.set_meta(SHIMMER_META, true)
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween().set_loops()
	tw.tween_property(ctrl, "scale", Vector2(1.25, 1.25), 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ctrl, "modulate:a", 0.6, 0.7)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ctrl, "modulate:a", 1.0, 0.7)


## Card sounds: "pick" (lift), "place" (lands in the deck), "return" (back to the bag).
static func sound(kind: String) -> void:
	match kind:
		"pick":
			AudioManager.play_sfx_varied("card_draw", 1.15, 0.06, 1.0)
		"place":
			AudioManager.play_sfx_varied("card_play", 1.0, 0.05, 1.0)
		"return":
			AudioManager.play_sfx_varied("card_draw", 0.85, 0.05, 1.0)
		"shuffle":
			for i in range(3):
				AudioManager.play_sfx_varied("card_draw", 0.9 + 0.12 * i, 0.08, 2.0)
