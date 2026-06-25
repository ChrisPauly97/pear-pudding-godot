## Canonical owned-card instance dictionary builder.
##
## Both the single-player collection (`SaveManager.owned_cards`) and a multiplayer
## session character (`SessionState` member record, GID-095) persist card instances
## as plain JSON dicts. Factoring the shape here means `save_slot_*.json` and the
## session files can never drift apart — there is exactly one definition of an
## instance dict's keys.
##
## Callers: preload("res://game_logic/CardInstanceUtil.gd"). No scene deps —
## fully unit-testable.
extends RefCounted


## Build the canonical owned-card instance dict. `kills`, `battles_survived` and
## `custom_name` start at their fresh defaults (instance-stat tracking is added as
## the card is used). Mirrors the shape SaveManager persists in `owned_cards`.
static func make(uid: String, template_id: String, rarity: String, attack: int, health: int, cost: int) -> Dictionary:
	return {
		"uid": uid,
		"template_id": template_id,
		"rarity": rarity,
		"attack": attack,
		"health": health,
		"cost": cost,
		"kills": 0,
		"battles_survived": 0,
		"custom_name": "",
	}
