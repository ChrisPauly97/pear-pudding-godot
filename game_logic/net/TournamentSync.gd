## Pure bracket scheduling + wire format for host-run session tournaments
## (GID-104 / TID-386).
##
## Bracket algorithm: round-robin (every participant plays every other
## participant exactly once). Chosen over single-elimination because a 3-4
## player session tournament is small enough that single-elim would knock a
## player out after one loss (a poor "marquee event" for such a small group)
## and would need a bye for the 3-player case; round-robin needs no byes and
## its schedule is a flat list of pairs (not a tree), which keeps
## authority-side scheduling/broadcast/tests simple. Only one match runs at a
## time (the rest of the party auto-spectates via SceneManager.enter_pvp_spectator),
## so there is no need for a round/wave structure — matches are a single
## ordered list, resolved one at a time via `current_match`.
##
## Scene-free and fully unit-tested, mirroring `RatingMath.gd` / `AvatarSync.gd`.
## Callers: preload("res://game_logic/net/TournamentSync.gd"). No scene deps.
class_name TournamentSync
extends RefCounted

const MIN_PLAYERS: int = 3
const MAX_PLAYERS: int = 4

# ---------------------------------------------------------------------------
# Scheduling
# ---------------------------------------------------------------------------

## All unique pairings among `n` participant indices (0..n-1), in a fixed
## deterministic order (i<j). Each match dict: {a, b, winner, done}.
static func build_round_robin_matches(n: int) -> Array:
	var matches: Array = []
	for i in range(n):
		for j in range(i + 1, n):
			matches.append({"a": i, "b": j, "winner": -1, "done": false})
	return matches


## Total match count for `n` round-robin participants: n*(n-1)/2.
static func match_count(n: int) -> int:
	return n * (n - 1) / 2


## Flat per-player entry fee times player count — precomputed once so callers
## never need to re-derive the prize from the live bracket.
static func payout_pot(ante: int, num_players: int) -> int:
	return ante * num_players


# ---------------------------------------------------------------------------
# Bracket construction
# ---------------------------------------------------------------------------

## Builds a fresh bracket dict. `tokens`/`names` are parallel arrays (participant
## index -> identity). Returns {} (a defensive no-op) if the player count is
## out of the supported 3-4 range or the arrays don't line up — callers must
## check for an empty result before using it.
static func new_bracket(tokens: Array, names: Array, ante: int) -> Dictionary:
	var n: int = tokens.size()
	if n < MIN_PLAYERS or n > MAX_PLAYERS or names.size() != n:
		return {}
	return {
		"players": tokens.duplicate(),
		"names": names.duplicate(),
		"matches": build_round_robin_matches(n),
		"current_match": 0,
		"ante": ante,
		"pot": payout_pot(ante, n),
		"winner_idx": -1,
		"finished": false,
	}


## True once every match has a recorded result.
static func is_finished(bracket: Dictionary) -> bool:
	return bool(bracket.get("finished", false))


## The match currently awaiting a result, or {} if the bracket is empty/finished.
static func get_current_match(bracket: Dictionary) -> Dictionary:
	if bracket.is_empty():
		return {}
	var matches: Array = bracket.get("matches", [])
	var cur: int = int(bracket.get("current_match", 0))
	if bool(bracket.get("finished", false)) or cur < 0 or cur >= matches.size():
		return {}
	return matches[cur]


## Records the result of the current match (winner_participant_idx must be one
## of that match's two participants) and advances `current_match`. Marks the
## bracket `finished` + resolves `winner_idx` once every match has a result.
## A no-op (returns an unchanged duplicate) for an empty/already-finished
## bracket or a winner index that isn't actually in the current match —
## defensive so a stale/duplicate signal can never corrupt standings.
static func record_match_result(bracket: Dictionary, winner_participant_idx: int) -> Dictionary:
	var b: Dictionary = bracket.duplicate(true)
	var cur_match: Dictionary = get_current_match(b)
	if cur_match.is_empty():
		return b
	if winner_participant_idx != int(cur_match.get("a", -1)) \
			and winner_participant_idx != int(cur_match.get("b", -1)):
		return b
	var matches: Array = b["matches"]
	var cur: int = int(b["current_match"])
	var updated: Dictionary = (matches[cur] as Dictionary).duplicate()
	updated["winner"] = winner_participant_idx
	updated["done"] = true
	matches[cur] = updated
	b["matches"] = matches
	b["current_match"] = cur + 1
	if int(b["current_match"]) >= matches.size():
		b["finished"] = true
		b["winner_idx"] = compute_winner(b)
	return b


# ---------------------------------------------------------------------------
# Standings
# ---------------------------------------------------------------------------

## Wins per participant index, counting only completed matches.
static func wins_by_participant(bracket: Dictionary) -> Array:
	var n: int = (bracket.get("players", []) as Array).size()
	var wins: Array = []
	wins.resize(n)
	for i in range(n):
		wins[i] = 0
	for m: Variant in (bracket.get("matches", []) as Array):
		if m is Dictionary and bool((m as Dictionary).get("done", false)):
			var w: int = int((m as Dictionary).get("winner", -1))
			if w >= 0 and w < n:
				wins[w] = int(wins[w]) + 1
	return wins


## The winner's participant index of the single match between p1 and p2, or -1
## if they haven't played (or that match isn't done yet).
static func head_to_head_winner(bracket: Dictionary, p1: int, p2: int) -> int:
	for m: Variant in (bracket.get("matches", []) as Array):
		if not (m is Dictionary):
			continue
		var md: Dictionary = m
		var a: int = int(md.get("a", -1))
		var b: int = int(md.get("b", -1))
		if (a == p1 and b == p2) or (a == p2 and b == p1):
			if not bool(md.get("done", false)):
				return -1
			return int(md.get("winner", -1))
	return -1


## The tournament winner's participant index once every match has a result:
## most wins; a 2-way tie is broken by head-to-head; any other tie (3+-way, or
## a 2-way tie whose head-to-head is somehow unresolved) falls back to the
## lowest participant index so every peer's independently-computed copy of the
## bracket agrees. Returns -1 if the bracket is empty or any match is still
## pending (not actually finished yet).
static func compute_winner(bracket: Dictionary) -> int:
	var matches: Array = bracket.get("matches", [])
	if matches.is_empty():
		return -1
	for m: Variant in matches:
		if not (m is Dictionary) or not bool((m as Dictionary).get("done", false)):
			return -1
	var wins: Array = wins_by_participant(bracket)
	if wins.is_empty():
		return -1
	var best_w: int = -1
	for w: Variant in wins:
		if int(w) > best_w:
			best_w = int(w)
	var tied: Array[int] = []
	for i in range(wins.size()):
		if int(wins[i]) == best_w:
			tied.append(i)
	if tied.size() == 1:
		return tied[0]
	if tied.size() == 2:
		var h2h: int = head_to_head_winner(bracket, tied[0], tied[1])
		if h2h >= 0:
			return h2h
	var lowest: int = tied[0]
	for t: int in tied:
		if t < lowest:
			lowest = t
	return lowest


# ---------------------------------------------------------------------------
# Wire format (pure encode/decode, mirrors AvatarSync / PlayerIdentity)
# ---------------------------------------------------------------------------

## A defensive, canonical-key-set copy safe to send over an RPC (the bracket
## dict is already JSON-primitive, so this mainly guards against aliasing and
## missing keys — mirrors the "send the whole cached thing" pattern used by
## recv_leaderboard / recv_party_bounties_snapshot).
static func encode_bracket(bracket: Dictionary) -> Dictionary:
	return {
		"players": (bracket.get("players", []) as Array).duplicate(),
		"names": (bracket.get("names", []) as Array).duplicate(),
		"matches": (bracket.get("matches", []) as Array).duplicate(true),
		"current_match": int(bracket.get("current_match", 0)),
		"ante": int(bracket.get("ante", 0)),
		"pot": int(bracket.get("pot", 0)),
		"winner_idx": int(bracket.get("winner_idx", -1)),
		"finished": bool(bracket.get("finished", false)),
	}


## Defensive decode: never throws on garbage/partial/non-Dictionary input,
## always returns a dict with every key present.
static func decode_bracket(payload: Variant) -> Dictionary:
	if not (payload is Dictionary):
		return {
			"players": [], "names": [], "matches": [], "current_match": 0,
			"ante": 0, "pot": 0, "winner_idx": -1, "finished": false,
		}
	return encode_bracket(payload as Dictionary)
