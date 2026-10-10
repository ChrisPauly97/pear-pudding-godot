## UnlockLadder — what a new player unlocks, when, from whom, for how much
## (GID-141 / TID-587). The single source of truth for gradual onboarding.
##
## A level-up only makes an entry *available*. The player then has to visit the
## entry's trainer, read its `how_to` and pay `cost` gold to learn it, which
## stores its id in `SaveManager.learned_abilities`. Nothing on the ladder works
## until it is learned.
##
## Two kinds of row:
##   skill   — a technique card (GID-175); learning it grants the `tech_<id>`
##             card. `level_req` / `learn_cost` live in TechniqueDefs.DEFS
##             (never duplicated here)
##   feature — a game system (`feat_*`) with its own level/cost here
##
## Row keys: id, kind, trainer, title, how_to, and for features level_req, cost.
## Pure static data, no autoloads.
extends RefCounted

const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")

## Trainer ids → display names. Each is a Madrian NPC (TID-590).
const TRAINERS: Dictionary = {
	"combat": "Combat Trainer",
	"maiteln": "Maiteln",
	"bounty": "Bounty Master",
	"gravedigger": "Gravedigger",
	"merchant": "Merchant",
	"stable": "Stablemaster",
	"crafter": "Master Artisan",
}

## Trainer id → the stitched-town NPC entity id that teaches it (TID-590).
## Maiteln is his follower node (no fixed NPC), handled by MaitelnFollower.
const TRAINER_NPCS: Dictionary = {
	"combat": "trainer_madrian",
	"bounty": "bounty_master_madrian",
	"gravedigger": "gravedigger_madrian",
	"merchant": "merchant_8",
	"stable": "stable_master",
	"crafter": "crafter_madrian",
}

const FEAT_MINIONS: String = "feat_minions"
const FEAT_SPELLS: String = "feat_spells"
const FEAT_COMPANION: String = "feat_companion"
const FEAT_SKILLS: String = "feat_skills"
const FEAT_BOUNTIES: String = "feat_bounties"
const FEAT_NIGHT_HUNTS: String = "feat_night_hunts"
const FEAT_DIG: String = "feat_dig"
const FEAT_PHASE: String = "feat_phase"
const FEAT_SPIRE: String = "feat_spire"
const FEAT_PACKS: String = "feat_packs"
const FEAT_MOUNT: String = "feat_mount"
const FEAT_COOKING: String = "feat_cooking"
const FEAT_ALCHEMY: String = "feat_alchemy"
const FEAT_CRAFTING: String = "feat_crafting"
## GID-185 / TID-775: deck-rule rows — unlocks that expand what the deck can do.
const FEAT_TECH_SLOT: String = "feat_tech_slot"
const FEAT_HAND_SIZE: String = "feat_hand_size"
const FEAT_QUICK_DRAW: String = "feat_quick_draw"
const DECK_RULE_ROWS: Array[String] = [FEAT_TECH_SLOT, FEAT_HAND_SIZE, FEAT_QUICK_DRAW]
## Real-time draw interval multiplier once FEAT_QUICK_DRAW is learned.
const QUICK_DRAW_MULT: float = 0.85

## GID-185 / TID-774: every feature row also grants cards (spec Identity: progression grants
## cards). Learning the row deals one copy of each into the collection, once
## (`SaveManager.ladder_cards_granted`). FEAT_SKILLS grants its card by the chosen magic type
## (MAGIC_STARTER_CARDS), so it waits until a type is picked. Skill rows grant their technique
## card through TechniqueDefs instead.
const FEATURE_CARDS: Dictionary = {
	FEAT_MINIONS: ["wolf", "treant"],
	FEAT_SPELLS: ["dagger_throw", "insight"],
	FEAT_COMPANION: ["rally"],
	FEAT_BOUNTIES: ["scarab"],
	FEAT_NIGHT_HUNTS: ["shrouded_wraith"],
	FEAT_DIG: ["skeleton", "skeleton"],
	FEAT_COOKING: ["restore"],
	FEAT_PHASE: ["ghost", "ghost"],
	FEAT_ALCHEMY: ["siphon"],
	FEAT_SPIRE: ["flicker"],
	FEAT_PACKS: ["spark"],
	FEAT_CRAFTING: ["bulwark"],
	FEAT_MOUNT: ["flux_blinkfox"],
	FEAT_TECH_SLOT: ["dagger_throw"],
	FEAT_HAND_SIZE: ["insight"],
	FEAT_QUICK_DRAW: ["spark"],
}
## FEAT_SKILLS: magic type → the starter card of that type.
const MAGIC_STARTER_CARDS: Dictionary = {
	"light": "ember_cinder", "dark": "wither", "verdant": "bloom_sprout", "rift": "flux_skitter",
}

## Profession id (ProfessionDefs.PROFESSIONS keys) → the feature row that gates its
## crafting station. Gathering is never gated; only the stations are.
const PROFESSION_FEATURES: Dictionary = {
	"cooking": FEAT_COOKING,
	"alchemy": FEAT_ALCHEMY,
	"crafting": FEAT_CRAFTING,
}

## Level order. Strike (a starter-deck technique card) and auto-attack are known from the start.
const LADDER: Array[Dictionary] = [
	{"id": "mend", "kind": "skill", "trainer": "combat", "title": "Mend",
		"how_to": ("A technique card for your deck. Play Mend from your hand to start a 1.5 second cast "
			+ "that heals you for 6. Like every technique it goes back to the bottom of your deck once "
			+ "played, so it comes round again. Heal between the enemy's big swings, not during them.")},
	{"id": "kick", "kind": "skill", "trainer": "combat", "title": "Kick",
		"how_to": ("Some enemies cast spells: watch for the bar that fills over their head. Kick "
			+ "interrupts the cast outright, off the global cooldown. It's a card: hold it in your hand "
			+ "for the casts that hurt, and once played it goes back to the bottom of your deck.")},
	{"id": FEAT_MINIONS, "kind": "feature", "trainer": "combat", "level_req": 4, "cost": 40,
		"title": "Summoning Allies",
		"how_to": ("Your deck now joins the fight. Each battle you draw a hand of cards; drag an ally card "
			+ "onto one of your board slots to summon it (it costs mana). Allies fight beside you and "
			+ "soak up blows. Win a fight under an enemy's special condition and you can soulbind its "
			+ "signature card — watch the victory screen for the hunt line.")},
	{"id": FEAT_SPELLS, "kind": "feature", "trainer": "combat", "level_req": 5, "cost": 60,
		"title": "Casting Spell Cards",
		"how_to": ("Spell cards in your hand are no longer dead weight. Tap a spell to cast it: targeted spells "
			+ "ask you to tap a marked target, others show a Cast button. Spells don't stay on the board — "
			+ "they hit, heal or buff once. A spell that lands the final blow counts for some soulbinds.")},
	{"id": FEAT_COMPANION, "kind": "feature", "trainer": "maiteln", "level_req": 6, "cost": 80,
		"title": "Fighting Beside Maiteln",
		"how_to": ("Maiteln will stand with you in battle as your mentor. He brings a passive bonus to every "
			+ "fight and calls out advice while you learn. Choose or change your mentor from the "
			+ "Character page.")},
	{"id": FEAT_SKILLS, "kind": "feature", "trainer": "maiteln", "level_req": 7, "cost": 100,
		"title": "Your Magic & Skill Tree",
		"how_to": ("Open Menu → Skills and pick your magic — Light, Dark, Verdant or Rift. From level 10 "
			+ "every level gives a Skill Point to spend on its two branches: nodes that change how your "
			+ "cards play, and technique cards of their own. Read each branch before you commit.")},
	{"id": FEAT_BOUNTIES, "kind": "feature", "trainer": "bounty", "level_req": 8, "cost": 120,
		"title": "Bounty Contracts",
		"how_to": ("The bounty board by the well posts three new contracts every day: slay a kind of enemy, "
			+ "fight in a certain land, or open chests. Take up to three at once, finish them anywhere, "
			+ "then come back to any board to be paid.")},
	{"id": FEAT_NIGHT_HUNTS, "kind": "feature", "trainer": "bounty", "level_req": 9, "cost": 140,
		"title": "Night Hunts",
		"how_to": ("After sunset, spectral enemies drift out of the dark. They are tougher than anything that "
			+ "walks by day, but they drop better cards. They fade at dawn — hunt them while the moon is up.")},
	{"id": FEAT_DIG, "kind": "feature", "trainer": "gravedigger", "level_req": 10, "cost": 175,
		"title": "Skeleton Dig",
		"how_to": ("Your deck shapes the world. Carry four or more Skeleton-family cards and a Dig button "
			+ "appears (D on a keyboard): use it standing on a burial mound to unearth what lies beneath. "
			+ "Build your deck around it, and the world opens up.")},
	{"id": FEAT_COOKING, "kind": "feature", "trainer": "crafter", "level_req": 11, "cost": 90,
		"title": "Cooking",
		"how_to": ("Build a cooking fire in the town square or at your home. Cook the river trout, herbs and game "
			+ "you gather into foods; a cooked meal heals you and some carry a well-fed buff into your next fights.")},
	{"id": "guard", "kind": "skill", "trainer": "combat", "title": "Guard",
		"how_to": "Raise your guard to absorb the next 6 damage. Cast it just before a telegraphed heavy blow."},
	{"id": FEAT_PHASE, "kind": "feature", "trainer": "gravedigger", "level_req": 12, "cost": 220,
		"title": "Ghost Phase",
		"how_to": ("Carry four or more Ghost-family cards and a Phase button appears (G on a keyboard): for a few "
			+ "seconds you can walk straight through walls. Old ruins hide rooms nobody else can reach.")},
	{"id": "ember_lance", "kind": "skill", "trainer": "combat", "title": "Ember Lance",
		"how_to": "A technique card: a heavier strike for 9 with a 1 second cast."},
	{"id": FEAT_ALCHEMY, "kind": "feature", "trainer": "crafter", "level_req": 14, "cost": 120,
		"title": "Alchemy",
		"how_to": ("Brew potions at an alchemy table in the square or at your home. Herbs from the wilds and the "
			+ "garden make healing draughts, tonics and salves for your quick slots and your fights.")},
	{"id": "mana_tap", "kind": "skill", "trainer": "combat", "title": "Mana Tap",
		"how_to": "A light hit that siphons mana back. Use it when you're one short of a card."},
	{"id": FEAT_SPIRE, "kind": "feature", "trainer": "combat", "level_req": 15, "cost": 300,
		"title": "The Rifts",
		"how_to": ("Rifts are floors of ever-stronger foes. Pick a tier, fight floor to floor with your own deck, "
			+ "take a boon between floors, and beat the guardian to open the next tier. Each land has its "
			+ "own rift and its own record.")},
	{"id": FEAT_PACKS, "kind": "feature", "trainer": "merchant", "level_req": 15, "cost": 200,
		"title": "Card Packs",
		"how_to": ("The merchant will now sell you sealed card packs. Each pack holds several cards of rising "
			+ "rarity; every pack without a legendary makes the next one likelier.")},
	{"id": "sweep", "kind": "skill", "trainer": "combat", "title": "Sweep",
		"how_to": "A wide strike that clips every enemy minion for 3. Clears a crowded board."},
	{"id": FEAT_CRAFTING, "kind": "feature", "trainer": "crafter", "level_req": 17, "cost": 150,
		"title": "Crafting",
		"how_to": ("Forge and stitch gear at the workbench from the ore and hide you gather and win from beasts. "
			+ "Your skill sets the quality of what you make, up to epic. Higher skill unlocks harder recipes.")},
	{"id": "daze", "kind": "skill", "trainer": "combat", "title": "Daze",
		"how_to": "A weak stun that briefly delays the enemy. Off the global cooldown — a second Kick in a pinch."},
	{"id": FEAT_TECH_SLOT, "kind": "feature", "trainer": "combat", "level_req": 20, "cost": 250,
		"title": "A Fourth Technique",
		"how_to": ("Your deck can now carry four technique cards instead of three. Add another from your "
			+ "collection at the Deck Table — a second interrupt, a heal, or more damage. It still takes a deck slot.")},
	{"id": FEAT_HAND_SIZE, "kind": "feature", "trainer": "maiteln", "level_req": 22, "cost": 260,
		"title": "A Fuller Hand",
		"how_to": ("Maiteln teaches you to hold more at once: in real-time fights your hand holds one more card "
			+ "before draws stop, so a held Kick no longer crowds out your next play.")},
	{"id": FEAT_QUICK_DRAW, "kind": "feature", "trainer": "maiteln", "level_req": 25, "cost": 300,
		"title": "Quick Draw",
		"how_to": ("Your hands learn the deck's rhythm: in real-time fights you draw a card 15% sooner. "
			+ "A thin, fast deck now cycles its best cards even faster.")},
	{"id": FEAT_MOUNT, "kind": "feature", "trainer": "stable", "level_req": 40, "cost": 1000,
		"title": "Riding",
		"how_to": ("You've the seat for a proper mount now. Buy a horse at the stable, then tap Mount to ride "
			+ "much faster through the wilds. You dismount for battle and climb back on after.")},
]


## The feature that gates `profession`'s station, or "" when it has none.
static func profession_feature(profession: String) -> String:
	return str(PROFESSION_FEATURES.get(profession, ""))


## "" when a player who has `learned` may use `profession`'s station, else the
## message to show instead: which trainer teaches it and at what level.
static func station_block(profession: String, learned: Array) -> String:
	var id: String = profession_feature(profession)
	if id == "" or is_learned(id, learned):
		return ""
	return "Learn %s from the %s (level %d) to use this station." % [
		str(def(id).get("title", id)), trainer_name(trainer_for(id)), level_req(id)]


## The cards learning feature row `id` grants (TID-774); [] for skill rows, unknown ids, and
## FEAT_SKILLS before a magic type is chosen.
static func cards_for(id: String, magic_type: String) -> Array[String]:
	var out: Array[String] = []
	if id == FEAT_SKILLS:
		if MAGIC_STARTER_CARDS.has(magic_type):
			out.append(str(MAGIC_STARTER_CARDS[magic_type]))
		return out
	out.assign(FEATURE_CARDS.get(id, []))
	return out

## Deck rules for a player who knows `learned` (TID-775): technique cards per deck.
static func technique_slots(learned: Array) -> int:
	return TechniqueDefs.DECK_MAX + (1 if learned.has(FEAT_TECH_SLOT) else 0)

## Extra real-time hand cap.
static func hand_cap_bonus(learned: Array) -> int:
	return 1 if learned.has(FEAT_HAND_SIZE) else 0

## Real-time draw interval multiplier.
static func draw_interval_mult(learned: Array) -> float:
	return QUICK_DRAW_MULT if learned.has(FEAT_QUICK_DRAW) else 1.0

static func all() -> Array[Dictionary]:
	return LADDER

static func def(id: String) -> Dictionary:
	for row: Dictionary in LADDER:
		if str(row["id"]) == id:
			return row
	return {}

static func has(id: String) -> bool:
	return not def(id).is_empty()

static func level_req(id: String) -> int:
	var row: Dictionary = def(id)
	if str(row.get("kind", "")) == "skill":
		return int(TechniqueDefs.def(TechniqueDefs.card_for(id)).get("level_req", 0))
	return int(row.get("level_req", 0))

static func cost(id: String) -> int:
	var row: Dictionary = def(id)
	if str(row.get("kind", "")) == "skill":
		return int(TechniqueDefs.def(TechniqueDefs.card_for(id)).get("learn_cost", 0))
	return int(row.get("cost", 0))

static func trainer_for(id: String) -> String:
	return str(def(id).get("trainer", ""))

## The trainer NPC `npc_id` is, or "".
static func trainer_at(npc_id: String) -> String:
	for t: Variant in TRAINER_NPCS:
		if str(TRAINER_NPCS[t]) == npc_id:
			return str(t)
	return ""

static func trainer_name(trainer: String) -> String:
	return str(TRAINERS.get(trainer, trainer.capitalize()))

## True when `id` is usable: learned, or not a ladder entry at all (always on).
static func is_learned(id: String, learned: Array) -> bool:
	return learned.has(id) or not has(id)

## Toast for trying to use `id` before learning it.
static func locked_message(id: String) -> String:
	return "%s isn't learned yet — the %s teaches it at level %d." % [
		str(def(id).get("title", id)), trainer_name(trainer_for(id)), level_req(id)]

static func can_learn(id: String, level: int, coins: int, learned: Array) -> bool:
	return has(id) and not learned.has(id) and level >= level_req(id) and coins >= cost(id)

## Entries that become available at exactly `level`, in ladder order.
static func available_at(level: int) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in LADDER:
		if level_req(str(row["id"])) == level:
			out.append(str(row["id"]))
	return out

## Entries available (level reached) but not yet learned.
static func pending(level: int, learned: Array) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in LADDER:
		var id: String = str(row["id"])
		if not learned.has(id) and level >= level_req(id):
			out.append(id)
	return out

## `trainer`'s rows, in ladder order.
static func for_trainer(trainer: String) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in LADDER:
		if str(row["trainer"]) == trainer:
			out.append(str(row["id"]))
	return out

static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in LADDER:
		out.append(str(row["id"]))
	return out
