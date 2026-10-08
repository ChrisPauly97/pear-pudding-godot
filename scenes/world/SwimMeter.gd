## The swim stamina meter (GID-172 / TID-697): a small bar that floats just above the
## swimming hero (projected from the 3D head position each frame), shown while stamina is
## below full; it flashes red when low. Owned by the `Coastline` world module, which adds
## it to the WorldScene HUD layer and feeds it the stamina.
extends ProgressBar

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _Swimming = preload("res://game_logic/world/Swimming.gd")

const FILL := Color(0.35, 0.72, 0.95)
const FILL_LOW := Color(0.92, 0.3, 0.25)
## World units above the hero's feet the meter is pinned to.
const HEAD_HEIGHT: float = 2.2
const FLASH_RATE: float = 6.0

var _fill_style: StyleBoxFlat = null
var _low_style: StyleBoxFlat = null
var _time: float = 0.0


func _ready() -> void:
	show_percentage = false
	max_value = 1.0
	step = 0.0
	value = 1.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Stamina — swimming tires you; get back to shore before it runs out"
	_resize()
	get_viewport().size_changed.connect(_resize)


func _resize() -> void:
	var vh: float = get_viewport().get_visible_rect().size.y
	custom_minimum_size = Vector2(vh * 0.09, vh * 0.014)
	size = custom_minimum_size
	_fill_style = _UiUtil.make_style(FILL, int(vh * 0.004))
	_low_style = _UiUtil.make_style(FILL_LOW, int(vh * 0.004))
	add_theme_stylebox_override("background", _UiUtil.make_style(Color(0.05, 0.08, 0.12, 0.8), int(vh * 0.004)))
	add_theme_stylebox_override("fill", _fill_style)


## Shows `stamina` above the hero at `feet` (world), seen through `cam`; hidden when full.
func show_stamina(stamina: float, feet: Vector3, cam: Camera3D, delta: float) -> void:
	visible = stamina < 0.999 and cam != null
	if not visible:
		return
	_time += delta
	value = stamina
	var low: bool = stamina < _Swimming.LOW and fmod(_time * FLASH_RATE, 2.0) < 1.0
	add_theme_stylebox_override("fill", _low_style if low else _fill_style)
	var p: Vector2 = cam.unproject_position(feet + Vector3.UP * HEAD_HEIGHT)
	position = p - Vector2(size.x * 0.5, size.y)
