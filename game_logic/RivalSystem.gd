## Pure helpers for the Isfig rival encounter system.
## Tier selection is based on encounters won and player level — no side effects.
extends Node

static func get_rival_type(encounters_won: int, player_level: int) -> String:
	var base_tier: int = clamp(encounters_won, 0, 2)
	# Level nudge: if the player has outpaced the base tier, bump to the next.
	if player_level > (base_tier + 1) * 5 and base_tier < 2:
		base_tier += 1
	var tier_ids: Array[String] = ["rival_isfig_1", "rival_isfig_2", "rival_isfig_3"]
	return tier_ids[base_tier]
