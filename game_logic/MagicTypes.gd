## Single source of truth for the game's magic types and their sub-branches.
##
## Four top-level types, two branches each. Everything that needs to know what a
## magic type *is* — the skill tree UI, the card rune generator, the battlefield
## cost rules, the cross-magic currency economy — reads from these tables rather
## than hard-coding branch names. Adding a fifth type means adding one `TYPES`
## entry plus two `BRANCH_COLORS` entries; nothing else has to change.
##
## Not an autoload: pure static data, no per-session state. Preload it.
extends Object

## Every magic type, in the order the "Choose Your Path" modal shows them.
##
## | Key | Meaning |
## |---|---|
## | `display` | Player-facing type name |
## | `branches` | The type's two sub-branches, in tab order |
## | `color` | Type tint (choose-your-path header) |
## | `tagline` | One-line pitch under the type name |
## | `cross_currency` | Which currency a player OF this type spends to buy skills from another type |
const TYPES: Dictionary = {
	"light": {
		"display": "Light",
		"branches": ["ember", "dawn"],
		"color": Color(1.0, 1.0, 0.55),
		"tagline": "Fire, healing, and clarity",
		"cross_currency": "corruption",
	},
	"dark": {
		"display": "Dark",
		"branches": ["dusk", "ash"],
		"color": Color(0.75, 0.5, 1.0),
		"tagline": "Shadow, drain, and disruption",
		"cross_currency": "redemption",
	},
	"verdant": {
		"display": "Verdant",
		"branches": ["bloom", "thorn"],
		"color": Color(0.5, 0.9, 0.5),
		"tagline": "Growth, endurance, and retribution",
		"cross_currency": "corruption",
	},
	"rift": {
		"display": "Rift",
		"branches": ["flux", "fracture"],
		"color": Color(0.55, 0.8, 1.0),
		"tagline": "Tempo, transmutation, and unmaking",
		"cross_currency": "redemption",
	},
}

## Per-branch tint. Used by the skill tree tabs/connectors and by
## TextureGen's procedural spell rune. Every branch named in TYPES needs an
## entry here — test_magic_types asserts the two tables agree.
const BRANCH_COLORS: Dictionary = {
	"ember":    Color(1.0, 0.7, 0.4),
	"dawn":     Color(1.0, 1.0, 0.55),
	"dusk":     Color(0.7, 0.5, 1.0),
	"ash":      Color(0.65, 0.65, 0.65),
	"bloom":    Color(0.45, 0.9, 0.5),
	"thorn":    Color(0.75, 0.85, 0.3),
	"flux":     Color(0.4, 0.8, 1.0),
	"fracture": Color(0.9, 0.45, 0.75),
}

## Per-branch tint for the procedural pixel-art spell rune (TextureGen).
##
## Deliberately separate from BRANCH_COLORS: a rune is 32×32 pixel art that needs
## saturated, high-contrast colour, while BRANCH_COLORS has to stay legible as a
## UI tint behind white label text. The four original values are the ones
## TextureGen shipped with and are preserved exactly.
const RUNE_COLORS: Dictionary = {
	"ember":    Color(1.0, 0.35, 0.05),
	"dawn":     Color(1.0, 0.9, 0.4),
	"dusk":     Color(0.55, 0.1, 0.9),
	"ash":      Color(0.55, 0.55, 0.65),
	"bloom":    Color(0.2, 0.85, 0.3),
	"thorn":    Color(0.65, 0.85, 0.1),
	"flux":     Color(0.15, 0.7, 1.0),
	"fracture": Color(0.95, 0.2, 0.65),
}

## Each type's *signature* branch — the one whose cards accrue that type's
## cross-magic currency when played. Exactly one per type.
##
## This is the rule Dawn and Dusk already followed before the table existed:
## playing Dawn cards earned corruption points, which is what a Light player
## spends. The currency was never "the Dawn currency"; Dawn is just Light's
## signature branch.
const CURRENCY_BRANCHES: Array[String] = ["dawn", "dusk", "bloom", "fracture"]

## Cross-magic points earned per signature-branch card played in a won battle.
const POINTS_PER_CARD: int = 1

static func all_types() -> Array[String]:
	var result: Array[String] = []
	for k in TYPES.keys():
		result.append(str(k))
	return result

static func is_valid_type(magic_type: String) -> bool:
	return TYPES.has(magic_type)

## The type's two sub-branches, in tab order. Empty for an unknown type.
static func branches_for(magic_type: String) -> Array[String]:
	var result: Array[String] = []
	if not TYPES.has(magic_type):
		return result
	for b in (TYPES[magic_type] as Dictionary).get("branches", []) as Array:
		result.append(str(b))
	return result

## The type that owns `branch`, or "" if no type claims it. Derived from TYPES
## rather than stored, so a branch can never be listed under one type and
## attributed to another.
static func type_for_branch(branch: String) -> String:
	for k in TYPES.keys():
		var branches: Array = (TYPES[k] as Dictionary).get("branches", []) as Array
		if branches.has(branch):
			return str(k)
	return ""

static func display_name(magic_type: String) -> String:
	if not TYPES.has(magic_type):
		return magic_type.capitalize()
	return str((TYPES[magic_type] as Dictionary).get("display", magic_type.capitalize()))

static func tagline(magic_type: String) -> String:
	if not TYPES.has(magic_type):
		return ""
	return str((TYPES[magic_type] as Dictionary).get("tagline", ""))

static func type_color(magic_type: String) -> Color:
	if not TYPES.has(magic_type):
		return Color.WHITE
	return (TYPES[magic_type] as Dictionary).get("color", Color.WHITE) as Color

static func branch_color(branch: String) -> Color:
	return BRANCH_COLORS.get(branch, Color.WHITE) as Color

## Rune tint for `branch`. Falls back to the pale blue TextureGen has always
## used for cards with no magic branch.
static func branch_rune_color(branch: String) -> Color:
	return RUNE_COLORS.get(branch, Color(0.5, 0.8, 1.0)) as Color

## The two-line blurb shown under a type's name in the choose-your-path modal,
## e.g. "Ember & Dawn\nFire, healing, and clarity".
static func branch_summary(magic_type: String) -> String:
	var branches: Array[String] = branches_for(magic_type)
	var names: Array[String] = []
	for b: String in branches:
		names.append(b.capitalize())
	return "%s\n%s" % [" & ".join(names), tagline(magic_type)]

## The currency a player of `magic_type` spends on cross-magic unlocks.
## Returns "corruption" for life-aligned types, "redemption" for entropy-aligned
## ones. Falls back to "corruption" for an unset/unknown type so the skill tree
## still renders a coherent price rather than a blank one.
static func cross_currency(magic_type: String) -> String:
	if not TYPES.has(magic_type):
		return "corruption"
	return str((TYPES[magic_type] as Dictionary).get("cross_currency", "corruption"))

## The currency accrued by playing a card of `branch`, or "" if that branch is
## not its type's signature branch.
static func currency_for_branch(branch: String) -> String:
	if not CURRENCY_BRANCHES.has(branch):
		return ""
	return cross_currency(type_for_branch(branch))
