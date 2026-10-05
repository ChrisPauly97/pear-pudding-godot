## UnlockLadder — what a new player unlocks, when, from whom, for how much
## (GID-141 / TID-587). The single source of truth for gradual onboarding.
##
## A level-up only makes an entry *available*. The player then has to visit the
## entry's trainer, read its `how_to` and pay `cost` gold to learn it, which
## stores its id in `SaveManager.learned_abilities`. Nothing on the ladder works
## until it is learned.
##
## Two kinds of row:
##   skill   — a skill-bar ability; `level_req` / `learn_cost` live in
##             SkillBar.ABILITIES (never duplicated here)
##   feature — a game system (`feat_*`) with its own level/cost here
##
## Row keys: id, kind, trainer, title, how_to, and for features level_req, cost.
## Pure static data, no autoloads.
extends RefCounted

const SkillBar = preload("res://game_logic/battle/SkillBar.gd")

## Trainer ids → display names. Each is a Madrian NPC (TID-590).
const TRAINERS: Dictionary = {
	"combat": "Combat Trainer",
	"maiteln": "Maiteln",
	"bounty": "Bounty Master",
	"gravedigger": "Gravedigger",
	"merchant": "Merchant",
	"stable": "Stablemaster",
}

## Trainer id → the stitched-town NPC entity id that teaches it (TID-590).
## Maiteln is his follower node (no fixed NPC), handled by MaitelnFollower.
const TRAINER_NPCS: Dictionary = {
	"combat": "trainer_madrian",
	"bounty": "bounty_master_madrian",
	"gravedigger": "gravedigger_madrian",
	"merchant": "merchant_8",
	"stable": "stable_master",
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

## Level order. Strike and auto-attack are known from the start (SkillBar.ALWAYS_KNOWN).
const LADDER: Array[Dictionary] = [
	{"id": "mend", "kind": "skill", "trainer": "combat", "title": "Mend",
		"how_to": ("A healing spell for your skill bar. Tap Mend in a fight (or press its number key) to "
			+ "start a 1.5 second cast that heals you for 6. It shares the global cooldown and costs mana, "
			+ "and a hit can't stop it — but you stand still while you cast, so heal between the "
			+ "enemy's big swings, not during them.")},
	{"id": "kick", "kind": "skill", "trainer": "combat", "title": "Kick",
		"how_to": ("Some enemies cast spells: watch for the bar that fills over their head. Kick "
			+ "interrupts the cast outright. It is off the global cooldown, so you can Kick in the middle "
			+ "of anything else — but it has its own 12 second cooldown, so save it for the casts that hurt.")},
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
		"how_to": ("Every level you've gained has banked a Skill Point. Open Menu → Skills, pick your magic — "
			+ "Light, Dark, Verdant or Rift — and spend points on its two branches. The choice shapes "
			+ "which spells you draw strength from, so read each branch before you commit.")},
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
	{"id": "guard", "kind": "skill", "trainer": "combat", "title": "Guard",
		"how_to": "Raise your guard to absorb the next 6 damage. Cast it just before a telegraphed heavy blow."},
	{"id": FEAT_PHASE, "kind": "feature", "trainer": "gravedigger", "level_req": 12, "cost": 220,
		"title": "Ghost Phase",
		"how_to": ("Carry four or more Ghost-family cards and a Phase button appears (G on a keyboard): for a few "
			+ "seconds you can walk straight through walls. Old ruins hide rooms nobody else can reach.")},
	{"id": "ember_lance", "kind": "skill", "trainer": "combat", "title": "Ember Lance",
		"how_to": "A heavier strike for 9 with a 1 second cast. Weave it between free Strikes."},
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
	{"id": "daze", "kind": "skill", "trainer": "combat", "title": "Daze",
		"how_to": "A weak stun that briefly delays the enemy. Off the global cooldown — a second Kick in a pinch."},
	{"id": FEAT_MOUNT, "kind": "feature", "trainer": "stable", "level_req": 40, "cost": 1000,
		"title": "Riding",
		"how_to": ("You've the seat for a proper mount now. Buy a horse at the stable, then tap Mount to ride "
			+ "much faster through the wilds. You dismount for battle and climb back on after.")},
]


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
		return int(SkillBar.def(id).get("level_req", 0))
	return int(row.get("level_req", 0))

static func cost(id: String) -> int:
	var row: Dictionary = def(id)
	if str(row.get("kind", "")) == "skill":
		return int(SkillBar.def(id).get("learn_cost", 0))
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
