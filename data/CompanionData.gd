extends Resource

@export var companion_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## "extra_mana" — start battles with +passive_value mana (one-time at battle start)
## "draw_card"  — draw passive_value extra card(s) at each player turn start
## "hero_armor" — hero starts with passive_value armor (one-time at battle start)
@export var passive_type: String = ""
@export var passive_value: int = 1
## Story flag that must be set for this companion to be unlockable. "" = always available.
@export var unlock_story_flag: String = ""
@export var portrait: Texture2D = null
