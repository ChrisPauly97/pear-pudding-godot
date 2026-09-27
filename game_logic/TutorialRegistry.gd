extends RefCounted

const _DATA: Dictionary = {
	"skill_tree": {
		"title": "Skill Tree",
		"body": ("Spend Skill Points to unlock passive and active abilities. Skill Points are earned by leveling up — "
				+ "check the XP bar at the bottom of the screen. Skills unlock from top to bottom; each row requires "
				+ "the row above it to be unlocked first."),
	},
	"coins": {
		"title": "Coins",
		"body": ("Coins are the main currency. Earn them by winning battles and finding chests. Spend them at Merchant "
				+ "NPCs to buy new cards for your collection."),
	},
	"essence": {
		"title": "Essence",
		"body": ("Essence is a crafting resource earned by scrapping cards you don't need. Use it in the Inventory to "
				+ "craft specific cards directly — so you're never stuck waiting for a lucky drop."),
	},
	"mana": {
		"title": "Mana",
		"body": ("Mana is your battle resource. You start each game with 1 mana and gain 1 more each turn, up to a "
				+ "maximum of 10. Play cards whose cost fits within your available mana each turn."),
	},
	"card_rarity": {
		"title": "Card Rarity",
		"body": ("Cards come in four rarities: Common (grey), Uncommon (green), Rare (blue), and Legendary (gold). "
				+ "Rarer cards have stronger effects and are harder to obtain — but you can craft any card using "
				+ "Essence in the Inventory."),
	},
	"tap_and_hold": {
		"title": "Inspect Cards",
		"body": ("Hold any card for half a second to see its full details — stats, description, and "
				+ "abilities.\n\nWorks in battle, your inventory, and the shop."),
	},
	"tap_to_cast": {
		"title": "Casting Spells",
		"body": ("Tap a spell card to cast it — targeted spells ask you to tap a marked target, others show a Cast "
				+ "button.\n\nTap ✕ Cancel at the top of the screen to back out of a spell or an attack."),
	},
	"spire_intro": {
		"title": "The Endless Spire",
		"body": ("Each floor holds one enemy. Defeat it and choose one of three cards to add to your run deck — your "
				+ "permanent collection stays untouched.\n\nHigher floors offer rarer cards. How far can you climb?"),
	},
	"night_hunts": {
		"title": "Night Hunts",
		"body": ("Spectral enemies roam the world after sunset. They drop better loot — but are far more dangerous. "
				+ "Fight them for rare cards, or retreat to town before dawn."),
	},
	"party_panel": {
		"title": "Party",
		"body": ("The Party button gathers everything you share with your co-op session in one place: the roster, loot "
				+ "rules, the shared stash, the leaderboard, Ghost Duels, Team Duel, and Dungeon Crawl."),
	},
	"soulbinding": {
		"title": "Soulbinding",
		"body": ("Every enemy type guards a signature card you can't buy or craft — you can only capture it by winning "
				+ "in a special way.\n\nThe Soulbind line on the victory screen shows this enemy's capture "
				+ "condition. Win while meeting it and the signature card joins your collection forever."),
	},
	"cantrips": {
		"title": "Deck Abilities",
		"body": ("Your deck shapes the world. Carry 4 or more cards of a family and you unlock an overworld ability — "
				+ "its button appears on the left of the screen.\n\n4+ Skeleton-family cards let you Dig buried "
				+ "mounds for loot. 4+ Ghost-family cards let you Phase through walls."),
	},
	# Real-time combat onboarding (GID-135 / TID-553): one-shot, shown the first time each moment happens.
	"rt_intro": {
		"title": "Real-Time Combat",
		"body": ("Fights happen live. Your weapon attacks on its own: watch the bar under your hero fill.\n\n"
				+ "Press Strike (1) to hit harder. It costs a little mana, then recharges. A dark shade drains "
				+ "off the button until it's ready again."),
	},
	"rt_skill_mend": {
		"title": "New Skill: Mend",
		"body": ("Mend (2) heals you. It takes a moment to cast: watch the cast bar, and don't get hit too "
				+ "often or it slows down.\n\nYour health carries over between fights, so heal when you're low."),
	},
	"rt_skill_kick": {
		"title": "New Skill: Kick",
		"body": ("Enemies cast too: a bar fills on their portrait before they summon or cast.\n\nPress Kick (3) "
				+ "while it's filling to interrupt it. Kick doesn't wait for your other skills to recharge."),
	},
	"rt_cards": {
		"title": "Your Cards",
		"body": ("Your deck joins the fight. You draw a card every few seconds.\n\nTap a card to play it: spells "
				+ "hit hard, units fight beside you. After any card or skill, a shade sweeps down your hand "
				+ "and skills — when it's gone you can act again."),
	},
	"rt_low_hp": {
		"title": "Low Health!",
		"body": "You're badly hurt. Press Mend (2) to heal before you fall.",
	},
	"rt_enemy_cast": {
		"title": "The Enemy Is Casting!",
		"body": ("See the bar filling on the enemy's portrait? Press Kick (3) now to interrupt it — the spell "
				+ "fails and it has to start over."),
	},
	"rt_out_of_mana": {
		"title": "Out of Mana",
		"body": ("No mana for skills right now. Your weapon keeps attacking on its own, and mana refills a few "
				+ "seconds after you stop spending it."),
	},
	"rt_ally": {
		"title": "Command Your Ally",
		"body": ("Your unit fights for you. When its bar turns green it's ready: tap it, then tap an enemy "
				+ "to attack.\n\nHitting a casting enemy with an Ally also interrupts it."),
	},
	"rt_add": {
		"title": "Another Enemy!",
		"body": ("A second enemy has joined the fight. The gold ring shows who you're attacking: tap an enemy "
				+ "or one of its minions to switch targets. Beat them all to win."),
	},
}

static func get_entry(popup_id: String) -> Dictionary:
	if _DATA.has(popup_id):
		return _DATA[popup_id] as Dictionary
	return {}
