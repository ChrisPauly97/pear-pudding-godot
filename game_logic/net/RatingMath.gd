## Pure ELO/MMR rating math for PvP duels (GID-102 / TID-370).
##
## Scene-free and fully unit-testable, mirroring `BattleNetProtocol` / `AvatarSync`.
## The **authority** (host in the listen-server model, dedicated server in GID-097)
## calls `updated()` for each combatant after a duel and writes the result into the
## GID-095 `SessionState` character record (`pvp_rating` / `pvp_games`). Clients never
## rate themselves — only the authority owns the update (isolation invariant).
##
## Standard ELO: `expected(a, b) = 1 / (1 + 10^((b - a) / 400))`,
## `new = round(r + K * (score - expected))`. `score` is 1.0 for a win, 0.0 for a loss
## (0.5 reserved for a future draw). K is larger during a placement window so a new
## player converges quickly, then settles to `K_BASE`.
##
## Integer-stable (returns `int`) and JSON-primitive — no engine objects.
## Callers: preload("res://game_logic/net/RatingMath.gd"). No scene dependencies.
class_name RatingMath
extends RefCounted

## Every character starts here (mirrors SessionState.make_starter_character).
const START_RATING: int = 1000

## Rating can never drop below this — keeps the ladder readable and avoids negatives.
const MIN_RATING: int = 100

## ELO divisor controlling how steep the expected-score curve is.
const SCALE: float = 400.0

## Settled K-factor once a player is out of placement.
const K_BASE: int = 32

## Higher K during placement so early results move the rating fast.
const K_PLACEMENT: int = 64

## Number of games a player is considered "in placement" (higher K).
const PLACEMENT_GAMES: int = 10


## Expected score of player A against player B in [0, 1]. Symmetric:
## `expected(a, b) + expected(b, a) == 1`.
static func expected_score(rating_a: int, rating_b: int) -> float:
	return 1.0 / (1.0 + pow(10.0, float(rating_b - rating_a) / SCALE))


## K-factor for a player who has already completed `games_played` rated games.
## Larger while still in the placement window so new ratings converge quickly.
static func k_factor(games_played: int) -> int:
	if games_played < PLACEMENT_GAMES:
		return K_PLACEMENT
	return K_BASE


## New rating after one duel. `score` is 1.0 (win), 0.0 (loss), or 0.5 (draw).
## `games_played` is the count *before* this duel (drives the placement K).
## Integer-stable and clamped to `MIN_RATING`.
static func updated(rating: int, opp_rating: int, score: float, games_played: int) -> int:
	var exp_score: float = expected_score(rating, opp_rating)
	var k: int = k_factor(games_played)
	var delta: float = float(k) * (clampf(score, 0.0, 1.0) - exp_score)
	return clamp_rating(rating + int(round(delta)))


## Floor a rating at `MIN_RATING`.
static func clamp_rating(rating: int) -> int:
	return rating if rating > MIN_RATING else MIN_RATING
