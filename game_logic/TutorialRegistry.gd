extends RefCounted

const _DATA: Dictionary = {
	"skill_tree": {
		"title": "Skill Tree",
		"body": "Spend Skill Points to unlock passive and active abilities. Skill Points are earned by leveling up — check the XP bar at the bottom of the screen. Skills unlock from top to bottom; each row requires the row above it to be unlocked first.",
	},
	"coins": {
		"title": "Coins",
		"body": "Coins are the main currency. Earn them by winning battles and finding chests. Spend them at Merchant NPCs to buy new cards for your collection.",
	},
	"essence": {
		"title": "Essence",
		"body": "Essence is a crafting resource earned by scrapping cards you don't need. Use it in the Inventory to craft specific cards directly — so you're never stuck waiting for a lucky drop.",
	},
	"mana": {
		"title": "Mana",
		"body": "Mana is your battle resource. You start each game with 1 mana and gain 1 more each turn, up to a maximum of 10. Play cards whose cost fits within your available mana each turn.",
	},
	"card_rarity": {
		"title": "Card Rarity",
		"body": "Cards come in four rarities: Common (grey), Uncommon (green), Rare (blue), and Legendary (gold). Rarer cards have stronger effects and are harder to obtain — but you can craft any card using Essence in the Inventory.",
	},
}

static func get_entry(popup_id: String) -> Dictionary:
	if _DATA.has(popup_id):
		return _DATA[popup_id] as Dictionary
	return {}
