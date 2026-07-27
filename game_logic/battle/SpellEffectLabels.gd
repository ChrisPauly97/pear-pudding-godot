## Player-facing wording for every spell and Emergence effect id.
##
## Both surfaces that describe a card read from here: the in-battle card face
## (CardViewBuilder) and the full-card inspect overlay (CardInspectOverlay).
## They previously kept private copies of these tables with a "keep both in
## sync" comment, and had already drifted apart on deal_damage_single.
##
## Adding a spell effect means adding one entry here — test_spell_effect_labels
## fails if any card in CardRegistry uses an effect with no label.
extends Object

const SPELL: Dictionary = {
	"deal_damage_single":  "Deal [power] damage to one target",
	"deal_damage_all":     "Deal [power] damage to all enemy minions",
	"deal_damage_random":  "Deal [power] damage to a random enemy",
	"debuff_attack":       "Reduce all enemy minion attack by [power]",
	"destroy_low_hp":      "Destroy all enemy minions with [power] or less HP",
	"resurrect_last":      "Resurrect the last friendly minion that died",
	"heal_single":         "Restore [power] HP to a friendly minion",
	"heal_all":            "Restore [power] HP to all friendly minions",
	"shield_minion":       "Give [power] armor to a friendly minion",
	"buff_attack":         "Give a friendly minion +[power] attack",
	"lifesteal_hit":       "Deal [power] damage; restore that much HP to your hero",
	"mana_drain":          "Remove [power] mana from the enemy hero",
	"curse_minion":        "Reduce an enemy minion's attack and HP by [power]",
	"draw_card":           "Draw [power] card(s)",
	"bless_slot":          "Bless a board slot — the next minion placed there gains +[power] ATK",
	"ward_slot":           "Ward a board slot — the next minion placed there gains Shroud",
	"deal_damage_hero":    "Deal [power] damage to the enemy hero",
	"apply_poison_single": "Poison a minion for [power] damage per turn",
	"apply_poison_all":    "Poison all enemy minions for [power] damage per turn",
	"grant_surge":         "Give a friendly minion Surge",
	"double_attack":       "A friendly minion attacks twice this turn",
	"buff_attack_all":     "Give all your minions +[power] attack",
	"heal_hero":           "Restore [power] HP to your hero",
	"armor_hero":          "Give your hero [power] armor",
	"grant_ward":          "Give a friendly minion Ward",
	"grant_shroud":        "Give a friendly minion Shroud",
	"grant_ward_all":      "Give all your minions Ward",
	"bind_minion":         "Strip all keywords from an enemy minion",
	"buff_health_all":     "Give all your minions +[power] health",
	"enemy_discard":       "Enemy discards [power] random card(s)",
	"freeze_single":       "Freeze an enemy minion for 1 turn",
	"freeze_all":          "Freeze all enemy minions for 1 turn",
	"drain_hero":          "Deal [power] to the enemy hero; restore that much HP to yours",
	"stun_single":         "Stun an enemy minion for [power] turn(s)",
	"summon_token":        "Summon [power] 1/1 Skeleton token(s)",
	"deal_damage_all_full":"Deal [power] damage to all enemy minions and their hero",
	"extra_turn":          "Take another turn after this one",
	"destroy_all_draw_3":  "Destroy every minion on both boards, then draw 3 cards",
	# Co-op PvE support cards (GID-100) — these target a chosen ally, not yourself.
	"ally_heal_hero":         "Restore [power] HP to an ally's hero",
	"ally_grant_ward_board":  "Give every minion on an ally's board Ward",
	"ally_buff_minion_all":   "Give every minion on an ally's board +[power]/+[power]",
	"ally_grant_mana":        "Give an ally [power] mana this turn",
	"ally_revive":            "Revive the last minion an ally lost",
}

const EMERGENCE: Dictionary = {
	"emergence_deal_damage":   "Emergence: Deal [power] damage to the enemy hero",
	"emergence_heal_hero":     "Emergence: Restore [power] HP to your hero",
	"emergence_draw":          "Emergence: Draw [power] card(s)",
	"emergence_buff_friendly": "Emergence: Give a friendly minion +[power] attack",
	"emergence_apply_poison":  "Emergence: Poison a random enemy minion for [power]",
}

## The spell line for `effect` with [power] substituted. An unlabelled effect
## falls back to its raw id, so a missing entry shows up on the card rather than
## rendering blank.
static func spell(effect: String, power: int) -> String:
	return str(SPELL.get(effect, effect)).replace("[power]", str(power))

static func emergence(effect: String, power: int) -> String:
	return str(EMERGENCE.get(effect, effect)).replace("[power]", str(power))
