class_name UiFx

# Shared button press feedback (scale tween + click SFX) — one attach point
# instead of re-deriving the same wiring at every button call site (TID-429).
# Idempotent: attaching twice to the same button is a no-op.

const _PRESS_SCALE: float = 0.93
const _PRESS_DUR: float = 0.08

## Wires scale-on-press feedback + a click SFX onto any BaseButton (Button,
## CheckBox, toggle-mode buttons, etc). Safe to call repeatedly on the same
## button (e.g. from a registry that re-registers on refresh).
static func attach(btn: BaseButton) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	if btn.has_meta("_uifx_attached"):
		return
	btn.set_meta("_uifx_attached", true)
	btn.button_down.connect(_on_button_down.bind(btn))
	btn.button_up.connect(_on_button_up.bind(btn))

static func _on_button_down(btn: BaseButton) -> void:
	if not is_instance_valid(btn) or btn.disabled:
		return
	btn.pivot_offset = btn.size * 0.5
	AudioManager.play_sfx("ui_click")
	var tw: Tween = btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(_PRESS_SCALE, _PRESS_SCALE), _PRESS_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func _on_button_up(btn: BaseButton) -> void:
	if not is_instance_valid(btn):
		return
	var tw: Tween = btn.create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, _PRESS_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Scales a panel from 0.96 → 1.0 while fading 0 → 1, for overlay "pop" opens.
## Doesn't gate mouse_filter, so input isn't swallowed during the pop.
static func pop_in(panel: Control, duration: float = 0.12) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.96, 0.96)
	panel.modulate.a = 0.0
	var tw: Tween = panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, duration)
