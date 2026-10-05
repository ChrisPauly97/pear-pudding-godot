## Battle hero panel looks (GID-164 / TID-679): one shared StyleBoxFlat per
## targeting state, built once and never mutated, so `CardViewBuilder.refresh_hero`
## (every frame in real-time battles) swaps an override only when the state changes.
extends RefCounted

static var _styles: Dictionary = {}  # key → StyleBoxFlat


## "spell" / "attack" (enemy hero targetable), "enemy", or "player".
static func key_for(is_enemy: bool, spell_targetable: bool, attack_targetable: bool) -> String:
	if not is_enemy:
		return "player"
	if spell_targetable:
		return "spell"
	return "attack" if attack_targetable else "enemy"


static func get_style(key: String) -> StyleBoxFlat:
	if _styles.has(key):
		return _styles[key] as StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	match key:
		"spell":
			style.bg_color = Color(0.1, 0.35, 0.45)
			style.border_color = Color.CYAN
			style.set_border_width_all(4)
		"attack":
			style.bg_color = Color(0.55, 0.15, 0.1)
			style.border_color = Color(1.0, 0.35, 0.2)
			style.set_border_width_all(3)
		"enemy":
			style.bg_color = Color(0.45, 0.1, 0.1)
		_:
			style.bg_color = Color(0.1, 0.2, 0.4)
	_styles[key] = style
	return style
