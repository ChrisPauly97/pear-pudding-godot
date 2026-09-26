extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## "weapon" | "armor" | "ring" | "trinket"
@export var slot: String = "weapon"
## "deck_inject" | "starting_mana" | "starting_hp" | "passive_atk"
@export var battle_effect_type: String = ""
## Bonus amount for starting_mana / starting_hp / passive_atk. Unused for deck_inject.
@export var battle_effect_value: int = 0
## Card id to inject into the draw pile (deck_inject only).
@export var injected_card_id: String = ""
## Number of copies to inject (deck_inject only).
@export var injected_card_count: int = 0
## Real-time main-hand swing interval in seconds (0 = unarmed speed from the
## combat tuning). Slower weapons hit proportionally harder per swing (GID-135).
@export var swing_speed: float = 0.0
