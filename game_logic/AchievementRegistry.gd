extends Object

# Static registry of all achievement definitions.
# condition_type values: "battles_won", "enemies_defeated", "cards_earned",
#   "biomes_visited", "chests_opened", "specific_flag",
#   "dawn_battle_won", "dusk_battle_won"

const ACHIEVEMENTS: Array = [
	{
		"id": "first_blood",
		"name": "First Blood",
		"description": "Win your first battle.",
		"condition_type": "battles_won",
		"target_value": 1,
		"reward_card_id": "",
	},
	{
		"id": "veteran",
		"name": "Battle Veteran",
		"description": "Win 10 battles.",
		"condition_type": "battles_won",
		"target_value": 10,
		"reward_card_id": "ancient_guardian",
	},
	{
		"id": "explorer",
		"name": "World Explorer",
		"description": "Visit all 5 biomes.",
		"condition_type": "biomes_visited",
		"target_value": 5,
		"reward_card_id": "",
	},
	{
		"id": "treasure_hunter",
		"name": "Treasure Hunter",
		"description": "Open 10 chests.",
		"condition_type": "chests_opened",
		"target_value": 10,
		"reward_card_id": "void_wyrm",
	},
	{
		"id": "card_collector",
		"name": "Card Collector",
		"description": "Earn 20 cards.",
		"condition_type": "cards_earned",
		"target_value": 20,
		"reward_card_id": "",
	},
	{
		"id": "chapter1_done",
		"name": "The Warning Given",
		"description": "Complete Chapter 1.",
		"condition_type": "specific_flag",
		"target_value": 1,
		"reward_card_id": "time_warp",
		"flag_key": "chapter1_complete",
	},
	{
		"id": "undead_slayer",
		"name": "Undead Slayer",
		"description": "Defeat 25 enemies.",
		"condition_type": "enemies_defeated",
		"target_value": 25,
		"reward_card_id": "",
	},
	{
		"id": "dawn_devotee",
		"name": "Dawn Devotee",
		"description": "Win a battle with 5 or more Dawn cards in your deck.",
		"condition_type": "dawn_battle_won",
		"target_value": 1,
		"reward_card_id": "soul_harvest",
	},
	{
		"id": "dusk_disciple",
		"name": "Dusk Disciple",
		"description": "Win a battle with 5 or more Dusk cards in your deck.",
		"condition_type": "dusk_battle_won",
		"target_value": 1,
		"reward_card_id": "phoenix_rise",
	},
]

static func get_all() -> Array:
	return ACHIEVEMENTS

static func get_achievement(id: String) -> Dictionary:
	for a: Dictionary in ACHIEVEMENTS:
		if a["id"] == id:
			return a
	return {}
