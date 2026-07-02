## Pure sealed-pool generation + wire helpers for Draft Duels (GID-104 / TID-385).
##
## Callers: preload("res://game_logic/net/DraftDuelGen.gd")
## No scene dependencies — fully unit-testable without a live connection.
##
## Both duelists derive an IDENTICAL sequence of NUM_ROUNDS "1-of-3" pick rounds
## from one shared integer seed (the challenger generates it; the responder's
## accept echoes it back — see NetSync.request_draft_duel/respond_draft_duel).
## Because both peers see the SAME options every round (not a shared/limited
## pool), there is nothing to arbitrate — each peer just picks independently, so
## no per-pick relay/conflict-resolution RPC is needed. Only the two *finished*
## decks cross the wire, once each, via NetSync.submit_draft_duel_deck.
##
## Round generation reuses game_logic/spire/SpireDraft.gd's tier-weighted 1-of-3
## logic (GID-038) rather than duplicating it — round index (1-based) is passed as
## the "floor" argument so later rounds skew toward higher tiers, mirroring the
## Spire's own draft escalation curve.
extends RefCounted

const SpireDraft = preload("res://game_logic/spire/SpireDraft.gd")
const CardInstanceUtil = preload("res://game_logic/CardInstanceUtil.gd")

const VERSION: int = 1

## Number of 1-of-3 rounds a duelist picks through; the resulting deck size (8)
## exactly matches IsoConst.DECK_MIN so a finished draft deck is always battle-legal.
const NUM_ROUNDS: int = 8
const OPTIONS_PER_ROUND: int = 3


# ---------------------------------------------------------------------------
# Sealed-pool round generation
# ---------------------------------------------------------------------------

## Deterministically generates NUM_ROUNDS rounds of OPTIONS_PER_ROUND card ids each,
## given a shared seed and a {card_id: template_dict} pool (built by the caller via
## CardRegistry, mirrors SpireDraftScene.setup). Same seed + same pool ⇒ same
## rounds on any peer — the RNG stream is seeded once, then consumed across all
## NUM_ROUNDS calls to SpireDraft.generate_picks (no per-round reseed).
## Returns an Array of NUM_ROUNDS entries, each an Array[String] of up to
## OPTIONS_PER_ROUND card ids (fewer only if the pool itself is smaller).
static func generate_rounds(seed_val: int, pool_templates: Dictionary) -> Array:
	var rounds: Array = []
	if pool_templates.is_empty():
		return rounds
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var draft := SpireDraft.new()
	for round_idx in range(NUM_ROUNDS):
		var picks: Array[String] = draft.generate_picks(round_idx + 1, rng, pool_templates)
		if picks.is_empty():
			continue
		rounds.append(picks)
	return rounds


## Pure tier lookup for a picked card's template — used both to color/label the
## pick UI and to tag the resulting transient instance's rarity. Delegates to
## SpireDraft so the tier definition never drifts between the two draft modes.
static func tier_for_template(tmpl: Dictionary) -> int:
	return SpireDraft.new().card_tier_from_template(tmpl)


# ---------------------------------------------------------------------------
# Wire helpers — the seed handshake payload (request_draft_duel / respond_draft_duel)
# ---------------------------------------------------------------------------

## Wraps the shared seed for the challenge RPC. A plain int would work as an RPC
## param too, but a versioned dict keeps this consistent with the rest of
## game_logic/net/'s pure-helper pattern (mirrors BattleNetProtocol.encode_state)
## and leaves room to carry NUM_ROUNDS for future format changes.
static func encode_seed(seed_val: int) -> Dictionary:
	return {"v": VERSION, "seed": seed_val, "rounds": NUM_ROUNDS}


## Defaulted, garbage-tolerant decode — never throws. Unknown/missing "seed" ⇒
## valid == false, seed == 0.
static func decode_seed(payload: Variant) -> Dictionary:
	if not (payload is Dictionary):
		return {"valid": false, "seed": 0, "rounds": NUM_ROUNDS}
	var d: Dictionary = payload
	if not d.has("seed"):
		return {"valid": false, "seed": 0, "rounds": NUM_ROUNDS}
	return {"valid": true, "seed": int(d.get("seed", 0)), "rounds": int(d.get("rounds", NUM_ROUNDS))}


# ---------------------------------------------------------------------------
# Transient card-instance builder — NEVER persisted. Drafted cards must never
# reach owned_cards / SaveManager / SessionState — only the in-memory GameState
# for the duration of the one duel.
# ---------------------------------------------------------------------------

const _RARITY_BY_TIER: Array[String] = ["common", "rare", "epic", "legendary"]

## Builds a transient owned-card-shaped instance dict for one drafted pick, using
## the template's own base stats — no rarity roll. Every duelist drafts from
## identical base-stat cards; that is the whole point of a sealed/draft format
## (zero collection-power advantage over a newcomer). `owner_token` + `round_idx`
## namespace the synthetic uid so it can never collide with a real owned_cards uid
## even if a caller mistakenly persisted it somewhere.
static func make_drafted_instance(template_id: String, tier: int, round_idx: int,
		owner_token: String, tmpl: Dictionary) -> Dictionary:
	var uid: String = "draft_%s_%d_%s" % [owner_token, round_idx, template_id]
	var rarity: String = _RARITY_BY_TIER[clampi(tier, 0, _RARITY_BY_TIER.size() - 1)]
	var attack: int = int(tmpl.get("attack", 0))
	var health: int = int(tmpl.get("health", 0))
	var cost: int = int(tmpl.get("cost", 1))
	return CardInstanceUtil.make(uid, template_id, rarity, attack, health, cost)
